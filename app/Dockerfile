FROM nginx:alpine
# IM8 Requirement: Containers must not run as root
RUN addgroup -S epiq && adduser -S epiq -G epiq
# Copy our fake "Engine" code
COPY src/ /usr/share/nginx/html/
EXPOSE 80
# Drop privileges
USER epiq
CMD ["nginx", "-g", "daemon off;"]
