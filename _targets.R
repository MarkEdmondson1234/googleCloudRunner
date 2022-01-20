library(targets)
list(targets::tar_target(file1, "mtcars.csv", format = "file"), 
    targets::tar_target(input1, read.csv(file1)), targets::tar_target(result1, 
        sum(input1$mpg)), targets::tar_target(result2, mean(input1$mpg)), 
    targets::tar_target(result3, max(input1$mpg)), targets::tar_target(result4, 
        min(input1$mpg)), targets::tar_target(merge1, paste(result1, 
        result2, result3, result4)))
