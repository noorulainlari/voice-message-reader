# Revokes old auto-generated 'Created via API' development certificates
# (made by Xcode cloud signing on CI) so the account doesn't hit Apple's certificate limit.
import jwt, time, os, json, urllib.request
kid = os.environ['ASC_KEY_ID']; iss = os.environ['ASC_ISSUER_ID']
key = open(os.path.expanduser(f'~/private_keys/AuthKey_{kid}.p8')).read()
tok = jwt.encode({'iss': iss, 'iat': int(time.time()), 'exp': int(time.time()) + 600, 'aud': 'appstoreconnect-v1'},
                 key, algorithm='ES256', headers={'kid': kid, 'typ': 'JWT'})
H = {'Authorization': 'Bearer ' + tok}
def call(url, method='GET'):
    req = urllib.request.Request(url, headers=H, method=method)
    with urllib.request.urlopen(req) as r:
        body = r.read()
        return json.loads(body) if body else {}
data = call('https://api.appstoreconnect.apple.com/v1/certificates?filter[certificateType]=DEVELOPMENT&limit=200')['data']
api = [c for c in data if 'Created via API' in (c['attributes'].get('name') or '')]
api.sort(key=lambda c: c['attributes'].get('expirationDate') or '')
print(f'development certs: {len(data)}, created via API: {len(api)}')
for c in api[:-4]:
    try:
        call(f"https://api.appstoreconnect.apple.com/v1/certificates/{c['id']}", 'DELETE')
        print('revoked old CI cert', c['attributes'].get('expirationDate'))
    except Exception as e:
        print('could not revoke', c['id'], e)
