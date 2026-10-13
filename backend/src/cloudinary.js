const cloudinary = require('cloudinary').v2;
const multer = require('multer');

const isConfigured = Boolean(
  process.env.CLOUDINARY_CLOUD_NAME?.trim() &&
  process.env.CLOUDINARY_API_KEY?.trim() &&
  process.env.CLOUDINARY_API_SECRET?.trim(),
);

if (isConfigured) {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME.trim(),
    api_key: process.env.CLOUDINARY_API_KEY.trim(),
    api_secret: process.env.CLOUDINARY_API_SECRET.trim(),
    secure: true,
  });
}

const IMAGE_EXTENSIONS = /\.(jpe?g|png|webp|gif|heic|heif|bmp)$/i;

// Files are kept in memory and streamed straight to Cloudinary; nothing is written to disk.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024, files: 1 },
  fileFilter(_req, file, callback) {
    if (file.mimetype.startsWith('image/') || IMAGE_EXTENSIONS.test(file.originalname || '')) {
      return callback(null, true);
    }
    const error = new Error('Only image files can be uploaded.');
    error.statusCode = 400;
    return callback(error);
  },
});

function requireCloudinary() {
  if (!isConfigured) {
    const error = new Error('Image uploads are not configured on the server (Cloudinary keys missing).');
    error.statusCode = 503;
    throw error;
  }
}

function cloudinaryError(error) {
  const status = error?.http_code;
  const wrapped = new Error(status === 403 || status === 401
    ? 'Cloudinary rejected the upload: the API key in backend/.env does not have upload permission. Create a key with full access in the Cloudinary dashboard.'
    : `Image upload failed: ${error?.message || 'unknown Cloudinary error'}`);
  wrapped.statusCode = 502;
  return wrapped;
}

function streamUpload(buffer, options) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { resource_type: 'image', ...options },
      (error, result) => (error
        ? reject(cloudinaryError(error))
        : resolve({ url: result.secure_url, publicId: result.public_id })),
    );
    stream.end(buffer);
  });
}

function uploadBuffer(buffer, folder) {
  requireCloudinary();
  return streamUpload(buffer, { folder, transformation: [{ width: 1600, crop: 'limit', quality: 'auto' }] });
}

// Some image hosts block Cloudinary's fetcher, so the image is downloaded here first.
async function uploadRemote(url, folder, publicId) {
  requireCloudinary();
  const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 EventBook-Seeder' } });
  if (!response.ok) throw new Error(`download failed with status ${response.status}`);
  const buffer = Buffer.from(await response.arrayBuffer());
  return streamUpload(buffer, { folder, public_id: publicId, overwrite: true });
}

async function deleteImage(publicId) {
  if (!publicId || !isConfigured) return;
  try {
    await cloudinary.uploader.destroy(publicId, { resource_type: 'image' });
  } catch (error) {
    console.error('Could not delete Cloudinary image', publicId, error.message);
  }
}

module.exports = { upload, uploadBuffer, uploadRemote, deleteImage, isCloudinaryConfigured: isConfigured };
