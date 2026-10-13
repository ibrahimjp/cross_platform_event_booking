// Usage: npm run create-admin -- <email> <password> ["Full Name"]
// Creates an admin account, or promotes (and re-enables) an existing account and sets its password.
require('dotenv').config();

const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const { User } = require('./models');

async function main() {
  const [email, password, ...nameParts] = process.argv.slice(2);
  if (!email || !email.includes('@') || !password || password.length < 8) {
    console.error('Usage: npm run create-admin -- <email> <password (8+ chars)> ["Full Name"]');
    process.exitCode = 1;
    return;
  }
  await mongoose.connect(process.env.MONGODB_URI);
  const normalized = email.trim().toLowerCase();
  const passwordHash = await bcrypt.hash(password, 12);
  const name = nameParts.join(' ').trim() || 'EventBook Admin';
  const existing = await User.findOne({ email: normalized });
  if (existing) {
    existing.role = 'admin';
    existing.isBlocked = false;
    existing.passwordHash = passwordHash;
    existing.tokenVersion = (existing.tokenVersion || 0) + 1;
    await existing.save();
    console.log(`Promoted ${normalized} to admin and set the new password.`);
  } else {
    await User.create({ name, email: normalized, passwordHash, role: 'admin' });
    console.log(`Created admin ${normalized}.`);
  }
  await mongoose.disconnect();
}

main().catch((error) => {
  console.error('Could not create the admin:', error.message);
  process.exitCode = 1;
});
