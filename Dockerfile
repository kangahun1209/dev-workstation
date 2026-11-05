FROM nginx:alpine
LABEL org.opencontainers.image.title="bellingham-dev-workstation"
COPY site/ /usr/share/nginx/html/
EXPOSE 80
