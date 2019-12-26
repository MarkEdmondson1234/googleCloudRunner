echo "
server {
    listen       \$${PORT};
    server_name  localhost;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}" > default.template

cat <<EOF >Dockerfile
FROM nginx
COPY . /usr/share/nginx/html
COPY default.template /etc/nginx/conf.d/default.template
CMD envsubst < /etc/nginx/conf.d/default.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'
EOF

cat default.template
cat Dockerfile
