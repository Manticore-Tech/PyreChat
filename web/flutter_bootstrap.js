{{flutter_js}}
{{flutter_build_config}}

// Do not block startup on Flutter's deprecated service-worker negotiation.
// The legacy worker in this project unregisters itself; let browser caching
// and Cloudflare's asset delivery handle the web resources instead.
_flutter.loader.load();
