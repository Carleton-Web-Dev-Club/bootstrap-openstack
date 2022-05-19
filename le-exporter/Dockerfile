FROM alpine
RUN apk add --update nodejs npm
COPY ./package.json .
RUN npm install --only=production
COPY src/ .
CMD ["node", "./main.js"]