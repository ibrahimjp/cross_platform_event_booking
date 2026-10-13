require('dotenv').config();

const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const { Booking, Event, User } = require('./models');
const { uploadRemote, isCloudinaryConfigured } = require('./cloudinary');

const DEMO_PASSWORD = 'password123';
const DEMO_USERS = [
  { name: 'EventBook Host', email: 'host@eventbook.ai', city: 'Mumbai' },
  { name: 'Alex Morgan', email: 'alex.morgan@eventbook.ai', city: 'Mumbai' },
];

// Dates are relative to the moment of seeding so the Today / Tomorrow / This Weekend
// filters always have something to show.
function at(daysFromToday, hours, minutes = 0) {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + daysFromToday);
  date.setHours(hours, minutes, 0, 0);
  return date;
}

function daysUntil(weekday) {
  const today = new Date().getDay();
  return (weekday - today + 7) % 7;
}

function seedEvents() {
  const friday = daysUntil(5);
  const saturday = daysUntil(6);
  const sunday = saturday + 1;
  return [
    {
      slug: 'sunburn-arena',
      title: 'Sunburn Arena: Electronic Experience',
      category: 'Music',
      startsAt: at(friday, 20),
      endsAt: at(friday + 1, 3),
      time: '8:00 PM - 3:00 AM',
      location: 'Mumbai',
      venue: 'DOME, NSCI, Worli, Mumbai',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDVp2Q4FSdQLudDZNY_dQCRzzvHqbj8fPAnyXpbSjARdEWCUF6nJHrgaUPBIUSp6bt1_xGdlKg1CV1Bw4mitsrXSGzzu53VtNpSL9zkslUwrWenndhfzrMt6EiPF0tnn52J8uN7Mi8WCqnQG2RWMa68aQN5yqJmPA4aISj0JfH-jVu-UvPSMTL_NmbKrmn4Ll2IRg3szG0TquSFxFqqHYMZMpzZIIr2vpt3zM4aVFjLcDHDWZmcsV_z',
      matchPercentage: 98,
      description: 'Based on your recent interest in electronic music and immersive audiovisual shows, we highly recommend this exclusive event in Mumbai. Step back into the future with state-of-the-art laser installations, holographics, and a curated lineup.',
      lineup: ['Kavinsky', 'The Midnight', 'FM-84', 'Special Guests'],
      attendeeCount: 4200,
      aiReason: 'Based on your past event history, you might want to secure VIP passes for exclusive backstage access.',
      isTrending: true,
      ticketCategories: [
        { id: 'tc-1', name: 'General Admission', price: 1499, description: 'Standard entry to main arena & dance floor', remaining: 45 },
        { id: 'tc-2', name: 'VIP Access', price: 3499, description: 'Elevated viewing deck, express bar & VIP lounge', remaining: 12 },
        { id: 'tc-3', name: 'VVIP Table (6 Pax)', price: 12000, description: 'Reserved couch table, complimentary bottle & dedicated server', remaining: 3 },
      ],
    },
    {
      slug: 'united-way-garba',
      title: 'United Way Garba',
      category: 'Festival',
      startsAt: at(0, 19),
      endsAt: at(9, 23, 59),
      time: '7:00 PM - 1:00 AM',
      location: 'Ahmedabad',
      venue: 'GMDC Ground, Ahmedabad',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDF5-JeQYXGli7Ykcwq44keDp2FFkO6tEYyshTIBCfH0zxdcrSki5-lQGUjherozQxeHoAxOBlvhEeyDJ78avpj-VpSax_Rf0-PJ9IfGnzcyEIl-DLw0-7aSB92KvawwTO-MYJcKFOM1XY4VF9CqET7KuW8vgZAkMGLO2A6BFBI_aKrBnahF9JMnqvnyHY_CJDNrMOtrTdH1ktilLsPvScX4Vnmx1ASdtdlzU0gEYKFtMHZBS7wdzrH',
      matchPercentage: 96,
      isGarbaSpecial: true,
      description: 'Experience the biggest Navratri celebration with traditional music, grand decorations, and over 30,000 dancers in full ethnic attire.',
      lineup: ['Rahul Munjariya', 'Traditional Garba Troupe'],
      attendeeCount: 15000,
      aiReason: 'Top trending Garba festival in Western India with traditional live orchestration.',
      ticketCategories: [
        { id: 'tc-g1', name: 'Pass - Daily Garba Entry', price: 1499, description: 'Single night access to main garba ground', remaining: 100 },
        { id: 'tc-g2', name: 'Season Pass (9 Nights)', price: 8999, description: 'Unlimited entry for all 9 nights of Navratri', remaining: 20 },
      ],
    },
    {
      slug: 'shankus-dandiya',
      title: 'Shankus Dandiya',
      category: 'Festival',
      startsAt: at(1, 19, 30),
      endsAt: at(9, 23, 59),
      time: '7:30 PM - 12:30 AM',
      location: 'Ahmedabad',
      venue: 'Shankus Water Park, Ahmedabad',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA7I7dL3ENwDQ8XkY_W1nDwh1g1mJev0WTOlzqSiEB6kTQUzFVXlrOebG6G4VpOIkugZE_q0SMOv0JjSu8ngunvzOcTwHjisv7m_TJJa9y3IwYVXwbhnq5LYE6O_XIi0V5gdg-jHD_rBh8HBNcTh98Ng0kwDgQYZZG0IVXVnFDLNzbXObWEMTmIcIVMNQcTQEECg9Pzw5fP0LPwToUe2O81OIOOxCW11F7KzsnyB1g20KJ0eSTIwyA6',
      matchPercentage: 93,
      isGarbaSpecial: true,
      description: 'A vibrant night of dandiya raas with live bands, authentic Gujarati cuisine stalls, and non-stop traditional entertainment.',
      lineup: ['Aishwarya Majmudar', 'Dandiya Beats Band'],
      attendeeCount: 8000,
      aiReason: 'Family-friendly festive ambiance with high energy and authentic food zones.',
      ticketCategories: [
        { id: 'tc-sd1', name: 'General Pass', price: 999, description: 'Entry to dandiya arena', remaining: 80 },
        { id: 'tc-sd2', name: 'VIP Couple Pass', price: 2499, description: 'Express entry + Food voucher included', remaining: 15 },
      ],
    },
    {
      slug: 'global-tech-leaders-summit',
      title: 'Global Tech Leaders Summit',
      category: 'Networking',
      startsAt: at(saturday, 10),
      endsAt: at(saturday, 18),
      time: '10:00 AM - 6:00 PM',
      location: 'Mumbai',
      venue: 'BKC, Mumbai',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD85uLhgtVA55IG1cSsALhjB0dwTWt8nSMfUKhilxH5RlEGXl45AHzMz0nbH3peH5OzFzTJZx8HhJx8kWhoVcrttaxB2BNJ2xyCsaA9U-o8wcVn2UWHE05CD3SE4AmKMD6XqaDEa3amvBoK5CE_ouZeINtibISwnbOYSMQw2h5N91Af-lfiGhpaVVq0BC-HNO-Hwc5SO-qYF90X21jzbTeMo_3a7K9dGO-LC1yTbI-p9KWIz2JSiJNY',
      matchPercentage: 92,
      isTrending: true,
      description: 'Connect with industry pioneers in a premium setting. Includes keynote speeches, roundtables, and curated AI networking sessions.',
      lineup: ['Dr. Sarah Chen (AI Researcher)', 'Rajiv Shah (Tech VC)', 'Elena Rostova (Design Director)'],
      attendeeCount: 1500,
      aiReason: 'Highly relevant to your profile as a product leader & technologist.',
      ticketCategories: [
        { id: 'tc-t1', name: 'Standard Delegate Pass', price: 3499, description: 'Access to all keynotes & networking lunch', remaining: 30 },
        { id: 'tc-t2', name: 'VIP Executive Pass', price: 7999, description: 'VIP lounge access + 1-on-1 investor matchmaking', remaining: 8 },
      ],
    },
    {
      slug: 'artisanal-culinary-tasting',
      title: 'Artisanal Culinary Tasting',
      category: 'Food',
      startsAt: at(sunday, 19),
      endsAt: at(sunday, 22),
      time: '7:00 PM - 10:00 PM',
      location: 'Bangalore',
      venue: 'Indiranagar, Bangalore',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBiGa1gAqCgoFP2WaJ8KALXqiiESJNUvrwa5nquyco9yMPSSgrknDCof4I48Si6DebSgjkuXnHuu4_lCqDcA4AwX8rkYbp5J-u4UnZ_nRIqmmZf1tONeGqmOm2J62nriqIkrMSVFQAmKvBVa7bLs9cJLnLYCUY7hSsOj2bEyR_ai3CH9j-1wpMTCt5Q_QqT5kzqhiIF2YDuEE9_HwuoBC9stTtsByaqUsun7zecZcOuhI78M4GuCiv6',
      matchPercentage: 89,
      isTrending: true,
      description: 'A curated 7-course tasting menu prepared by award-winning chefs, focusing on sustainable local ingredients and wine pairing.',
      lineup: ['Chef Marco V', 'Sommelier Priya Sharma'],
      attendeeCount: 120,
      aiReason: 'Exclusive intimate dining experience rated 4.9/5 by gourmet critics.',
      ticketCategories: [
        { id: 'tc-c1', name: '7-Course Chef Table', price: 4999, description: 'Full tasting menu with cocktail pairings', remaining: 6 },
      ],
    },
    {
      slug: 'digital-horizons-exhibition',
      title: 'Digital Horizons Exhibition',
      category: 'Cultural',
      startsAt: at(0, 11),
      endsAt: at(28, 20),
      time: '11:00 AM - 8:00 PM',
      location: 'Mumbai',
      venue: 'NGMA, Mumbai',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuC24SRtNQQntwYTEzl2ggZpq1QVY4TRY4Kd2IHcFnCLMJ_f5XszT6jXmD_veDmbjys_4NyK-2fsTwUKxkc6ymSbKr3ujJWVix9tnqlAQkU9GPYBzJ1fDc3DdLXDd9sWql0I6oHksmLeBe7snmO8xXZUGv2MzCbumGdjSU4KVrMUJ5Jgh5qwIiUBmg4Lw950OMGDtZtVyYBLyzUrlF4wfzLGWfEJeA8_R7539N2c6q3cPqYqn1-JsyK8',
      matchPercentage: 94,
      isTrending: true,
      description: 'Explore the intersection of AI and visual arts in this immersive gallery experience featuring international digital artists.',
      lineup: ['TeamLab Alumni', 'AI Generative Collective'],
      attendeeCount: 3400,
      aiReason: 'Free RSVP cultural event with interactive room installations.',
      ticketCategories: [
        { id: 'tc-d1', name: 'Free Admission RSVP', price: 0, description: 'General Entry Pass', remaining: 200 },
      ],
    },
  ];
}

async function ensureDemoUsers() {
  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 12);
  const users = [];
  for (const demo of DEMO_USERS) {
    let user = await User.findOne({ email: demo.email });
    if (!user) user = await User.create({ ...demo, passwordHash });
    users.push(user);
  }
  return users;
}

// Moves any seeded event images that are not on Cloudinary yet (e.g. after the API key
// is fixed) without touching the rest of the data.
async function copySeedImagesToCloudinary(log) {
  if (!isCloudinaryConfigured) return;
  const pending = await Event.find({ imagePublicId: '', imageUrl: /googleusercontent\.com/ });
  for (const event of pending) {
    const seed = seedEvents().find((candidate) => candidate.title === event.title);
    if (!seed) continue;
    try {
      const uploaded = await uploadRemote(event.imageUrl, 'eventbook/events', seed.slug);
      event.imageUrl = uploaded.url;
      event.imagePublicId = uploaded.publicId;
      await event.save();
      log(`Moved image for "${event.title}" to Cloudinary.`);
    } catch (error) {
      log(`Image for "${event.title}" is still on its original host (${error.message})`);
      return;
    }
  }
}

async function seedDatabase({ reset = false, log = console.log } = {}) {
  if (reset) {
    await Booking.deleteMany({});
    await Event.deleteMany({});
  }
  const [host] = await ensureDemoUsers();
  if (await Event.estimatedDocumentCount() > 0) {
    await copySeedImagesToCloudinary(log);
    return;
  }
  const events = seedEvents();
  for (const { slug, ...data } of events) {
    let imageUrl = data.imageUrl;
    let imagePublicId = '';
    if (isCloudinaryConfigured) {
      try {
        const uploaded = await uploadRemote(data.imageUrl, 'eventbook/events', slug);
        imageUrl = uploaded.url;
        imagePublicId = uploaded.publicId;
      } catch (error) {
        log(`Could not copy image for "${data.title}" to Cloudinary (${error.message}); using the original URL.`);
      }
    }
    const priceStarting = Math.min(...data.ticketCategories.map((ticket) => ticket.price));
    await Event.create({ ...data, imageUrl, imagePublicId, priceStarting, hostId: host._id });
    log(`Seeded event: ${data.title}`);
  }
}

if (require.main === module) {
  (async () => {
    await mongoose.connect(process.env.MONGODB_URI);
    await seedDatabase({ reset: process.argv.includes('--reset') });
    console.log(`Demo accounts (password "${DEMO_PASSWORD}"): ${DEMO_USERS.map((u) => u.email).join(', ')}`);
    await mongoose.disconnect();
  })().catch((error) => {
    console.error('Seeding failed:', error.message);
    process.exitCode = 1;
  });
}

module.exports = { seedDatabase };
