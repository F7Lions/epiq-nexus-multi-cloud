FROM nginx:alpine
# Copy our custom secure config
COPY nginx.conf /etc/nginx/nginx.conf

# Support running as non-root
RUN touch /tmp/nginx.pid && \
    chown -R nginx:nginx /tmp/nginx.pid /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

# Switch to the non-privileged user 'nginx'
USER nginx

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
USER nginx
EXPOSE 8080 
CMD ["nginx", "-g", "daemon off;"]