FROM nginx:alpine
RUN mkdir -p /usr/share/nginx/html
RUN echo "GCC App Running in Singapore" > /usr/share/nginx/html/index.html
RUN echo "healthy" > /usr/share/nginx/html/health
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
