library(targets)
list(tar_target(file1, "tests/targets/mtcars.csv", format = "file"), 
    tar_target(input1, read.csv(file1)), tar_target(result1, 
        sum(input1$mpg)))
