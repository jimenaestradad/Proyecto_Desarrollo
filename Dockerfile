# Packages the already-compiled Nori web app into an nginx image.
#   flutter build web --release
#   docker build -t nori .
#   docker run --rm -p 8080:80 nori     ->  http://localhost:8080
#
# This needs build/web to exist (the flutter build step above). To compile
# inside Docker instead, use Dockerfile.build -- slower, since it downloads
# the ~1.3 GB Flutter SDK image, but needs nothing installed locally.
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html
EXPOSE 80
