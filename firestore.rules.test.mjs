// Rules check against the local emulator. Run:
//   npx -y firebase-tools@latest emulators:exec --only firestore --project demo-bakery "node firestore.rules.test.mjs"
import assert from 'node:assert/strict';

const base = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/demo-bakery/databases/(default)/documents`;
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const token = (uid) => `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub: uid, user_id: uid, aud: 'demo-bakery', iss: 'https://securetoken.google.com/demo-bakery', iat: 0, exp: 9999999999 })}.`;

// Mirrors Cart.save(): set items map + server timestamp.
async function writeCart(asUid, docUid, items, extra = {}) {
  const fields = { items: { mapValue: { fields: Object.fromEntries(Object.entries(items).map(([k, v]) =>
    [k, typeof v === 'number' && Number.isInteger(v) ? { integerValue: v } : { stringValue: String(v) }])) } }, ...extra };
  const res = await fetch(`${base.replace(/\/documents$/, '/documents:commit')}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token(asUid)}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes: [{
      update: { name: `projects/demo-bakery/databases/(default)/documents/carts/${docUid}`, fields },
      updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
    }] }),
  });
  return res.status;
}
const read = async (asUid, docUid) =>
  (await fetch(`${base}/carts/${docUid}`, { headers: asUid ? { Authorization: `Bearer ${token(asUid)}` } : {} })).status;

assert.equal(await writeCart('alice', 'alice', { 'BRD-001': 2, 'PAS-001': 1 }), 200, 'owner writes valid cart');
assert.equal(await writeCart('alice', 'alice', {}), 200, 'owner empties cart');
assert.equal(await read('alice', 'alice'), 200, 'owner reads own cart');
assert.equal(await read('bob', 'alice'), 403, 'other user cannot read');
assert.equal(await writeCart('bob', 'alice', { 'BRD-001': 1 }), 403, 'other user cannot write');
assert.equal(await writeCart('alice', 'alice', { 'FAKE-01': 1 }), 403, 'unknown SKU rejected');
assert.equal(await writeCart('alice', 'alice', { 'BRD-001': 0 }), 403, 'zero qty rejected');
assert.equal(await writeCart('alice', 'alice', { 'BRD-001': 100 }), 403, 'qty > 99 rejected');
assert.equal(await writeCart('alice', 'alice', { 'BRD-001': 'lots' }), 403, 'non-int qty rejected');
assert.equal(await writeCart('alice', 'alice', { 'BRD-001': 1 }, { price: { integerValue: 0 } }), 403, 'extra field rejected');
const del = async (asUid, docUid) =>
  (await fetch(`${base}/carts/${docUid}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token(asUid)}` } })).status;
assert.equal(await del('bob', 'alice'), 403, 'other user cannot delete');
assert.equal(await del('alice', 'alice'), 200, 'owner deletes own cart (account deletion)');
assert.equal(await read(null, 'alice'), 403, 'signed-out read denied');
console.log('firestore.rules: all checks passed');
