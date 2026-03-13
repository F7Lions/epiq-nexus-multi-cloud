FROM nginx:alpine
# IM8 FIX: Patch Critical zlib vulnerability (CVE-2026-22184)
RUN apk update && apk upgrade && apk add zlib>1.3.1-r2

# IM8 Requirement: Containers must not run as root
RUN addgroup -S epiq && adduser -S epiq -G epiq
COPY src/ /usr/share/nginx/html/
EXPOSE 80
USER epiq
CMD ["nginx", "-g", "daemon off;"]