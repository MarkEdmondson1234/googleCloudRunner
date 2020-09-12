FROM trestletech/plumber
RUN ["install2.r", "xts","forecast","bigQueryR"]
COPY ["./", "./"]
ENTRYPOINT ["R", "-e", "pr <- plumber::plumb(rev(commandArgs()[1])); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT')))"]
CMD ["api.R"]
