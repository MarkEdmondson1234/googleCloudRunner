FROM nginx

COPY . /usr/share/nginx/html

COPY default.template /etc/nginx/conf.d/default.template

CMD envsubst < /etc/nginx/conf.d/default.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'
