const { authenticator } = require('otplib');
const qrcode = require('qrcode');
const db = require('./db');

function isTotpEnabled() {
  const s = db.prepare("SELECT value FROM settings WHERE key='totp_enabled'").get();
  return s && s.value === '1';
}

function getTotpSecret() {
  const s = db.prepare("SELECT value FROM settings WHERE key='totp_secret'").get();
  return s ? s.value : null;
}

function enableTotp(secret) {
  db.prepare("INSERT OR REPLACE INTO settings (key, value) VALUES ('totp_secret', ?), ('totp_enabled', '1')").run(secret);
}

function disableTotp() {
  db.prepare("DELETE FROM settings WHERE key='totp_secret'").run();
  db.prepare("DELETE FROM settings WHERE key='totp_enabled'").run();
}

async function generateQrCode(user, secret) {
  const otpauth = authenticator.keyuri(user, 'MTG Panel', secret);
  return qrcode.toDataURL(otpauth);
}

module.exports = {
  isTotpEnabled,
  getTotpSecret,
  enableTotp,
  disableTotp,
  generateQrCode,
  authenticator
};
