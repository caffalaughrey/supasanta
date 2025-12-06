## Hosting configuration for Web build

Enable cross-origin isolation to use Web Threads and Audio Worklet (improves performance on capable hosts):

- Cross-Origin-Opener-Policy: same-origin
- Cross-Origin-Embedder-Policy: require-corp

Serve `.wasm`, `.pck`, `.js`, `.ktx2`, `.ogg`, `.png`, `.webp` with compression and long cache:

- Cache-Control: public, max-age=31536000, immutable (for versioned files)
- Accept-Ranges: bytes
- Content-Type for `.wasm`: application/wasm

### Netlify `_headers`

```
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp

/*.wasm
  Content-Type: application/wasm
  Cache-Control: public, max-age=31536000, immutable

/*.pck
  Cache-Control: public, max-age=31536000, immutable

/*.js
  Cache-Control: public, max-age=31536000, immutable
```

### Nginx

```
location / {
  add_header Cross-Origin-Opener-Policy same-origin always;
  add_header Cross-Origin-Embedder-Policy require-corp always;
}
types { application/wasm wasm; }
location ~* \.(wasm|pck|js|ktx2|ogg|png|webp)$ {
  add_header Cache-Control "public, max-age=31536000, immutable";
}
```



