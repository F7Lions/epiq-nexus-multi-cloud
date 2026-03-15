FROM nginx:alpine

# IM8: Copy hardened custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# IM8: Support running as non-root user
RUN touch /tmp/nginx.pid && \
    chown -R nginx:nginx /tmp/nginx.pid /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

# IM8: Never run containers as root
USER nginx

# App listens on 8080 (non-privileged port, IM8 compliant)
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]