##Loading packages and folder of dataset
packages <- c('data.table', 'reshape2')
sapply(packages, require, character.only = TRUE, quietly = TRUE)
inputfolder <- file.path('UCI HAR Dataset')

##Reading data into R
subject_train_data <- fread(file.path(inputfolder, 'train', 'subject_train.txt'))
subject_test_data <- fread(file.path(inputfolder, 'test', 'subject_test.txt'))
activity_train_data <- fread(file.path(inputfolder, 'train', 'Y_train.txt'))
activity_test_data <- fread(file.path(inputfolder, 'test', 'Y_test.txt'))
train_data <- data.table(read.table(file.path(inputfolder, 'train', 'X_train.txt')))
test_data <- data.table(read.table(file.path(inputfolder, 'test', 'X_test.txt')))

##Merging data
subject_data <- rbind(subject_train_data, subject_test_data)
setnames(subject_data, 'V1', 'subject')

activity_data <- rbind(activity_train_data, activity_test_data)
setnames(activity_data, 'V1', 'activityNum')

data <- rbind(train_data, test_data)
subject_data <- cbind(subject_data, activity_data)
data <- cbind(subject_data, data)

setkey(data, subject, activityNum)

##Extracting SD and Mean
features_data <- fread(file.path(inputfolder, 'features.txt'))
setnames(features_data, names(features_data), c('featureNum', 'featureName'))
features_data <- features_data[grepl('mean\\(\\)|std\\(\\)', featureName)]
features_data$featureCode <- features_data[, paste0('V', featureNum)]

select <- c(key(data), features_data$featureCode)
data <- data[, select, with = FALSE]

##Naming activities in dataset
activity_name_data <- fread(file.path(inputfolder, 'activity_labels.txt'))
setnames(activity_name_data, names(activity_name_data), c('activityNum', 'activityName'))
data <- merge(data, activity_name_data, by = 'activityNum', all.x = TRUE)
setkey(data, subject, activityNum, activityName)
data <- data.table(melt(data, key(data), variable.name = 'featureCode'))
data <- merge(data, features_data[, list(featureNum, featureCode, featureName)], by = 'featureCode', 
            all.x = TRUE)

data$activity <- factor(data$activityName)
data$feature <- factor(data$featureName)

grepthis <- function(regex) {
      grepl(regex, data$feature)
}

## Features with 1 category
data$Jerk <- factor(grepthis('Jerk'), labels = c(NA, 'Jerk'))
data$Magnitude <- factor(grepthis('Mag'), labels = c(NA, 'Magnitude'))

## Features with 2 categories
categories <- 2
y <- matrix(seq(1, categories), nrow = categories)
x <- matrix(c(grepthis('^t'), grepthis('^f')), ncol = nrow(y))
data$Domain <- factor(x %*% y, labels = c('Time', 'Freq'))
x <- matrix(c(grepthis('Acc'), grepthis('Gyro')), ncol = nrow(y))
data$Instrument <- factor(x %*% y, labels = c("Accelerometer", "Gyroscope"))
x <- matrix(c(grepthis('BodyAcc'), grepthis('GravityAcc')), ncol = nrow(y))
data$Acceleration <- factor(x %*% y, labels = c(NA, 'Body', 'Gravity'))
x <- matrix(c(grepthis('mean()'), grepthis('std()')), ncol = nrow(y))
data$Variable <- factor(x %*% y, labels = c('Mean', 'SD'))

## Features with 3 categories
categories <- 3
y <- matrix(seq(1, categories), nrow = categories)
x <- matrix(c(grepthis('-X'), grepthis('-Y'), grepthis('-Z')), ncol = nrow(y))
data$Axis <- factor(x %*% y, labels = c(NA, 'X', 'Y', 'Z'))

##Tidying dataset
setkey(data, subject, activity, Domain, Acceleration,
       Instrument, Jerk, Magnitude, Variable,
       Axis)
tidy_data <- data[, list(count = .N, average = mean(value)), by = key(data)]

write.table(tidy_data, 'Dataset.txt', quote = FALSE, row.names = FALSE)

##Further tidying dataset
tidy_data_2 <- data.table(tidy_data)[, lapply(.SD, mean), by = 'subject,activity']
write.table(tidy_data_2, file = "TidyData.txt", row.names = FALSE)