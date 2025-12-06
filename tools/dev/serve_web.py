#!/usr/bin/env python3
import sys
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

class COOPCOEPHandler(SimpleHTTPRequestHandler):
	def end_headers(self) -> None:
		# Enable cross-origin isolation; required for threads/audio worklets
		self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
		self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
		super().end_headers()

	def guess_type(self, path: str) -> str:
		# Ensure correct mime types for web build assets
		if path.endswith('.wasm'):
			return 'application/wasm'
		if path.endswith('.pck'):
			return 'application/octet-stream'
		if path.endswith('.js'):
			return 'application/javascript'
		return super().guess_type(path)

def main() -> None:
	if len(sys.argv) < 2:
		print("Usage: serve_web.py <directory> [port]")
		sys.exit(1)
	directory = sys.argv[1]
	port = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
	addr = '127.0.0.1'
	if not os.path.isdir(directory):
		print(f"Directory not found: {directory}")
		sys.exit(2)
	os.chdir(directory)
	httpd = HTTPServer((addr, port), COOPCOEPHandler)
	print(f"Serving {directory} at http://{addr}:{port}")
	try:
		httpd.serve_forever()
	except KeyboardInterrupt:
		pass

if __name__ == '__main__':
	main()



