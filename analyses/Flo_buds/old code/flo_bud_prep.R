
##Dan B's begins to try and understand the realtionship between flowering and leafout based on Dan F's data beginning 11/22/16
#original data is Budburst Datasheet 2015-05-15.xlsx

# Setup: load packages, set working directory, read in the data.
rm(list=ls())
library(gdata)
library(nlme)
library(scales)
library(arm)
library(picante)
library(ade4)

setwd("~/Documents/git/buds/analyses")

#d <- read.csv("Budburst.csv")

d1 <- read.csv("Flo_buds/input/Budburst_Datasheet1_2015-05-15.csv") 
d2 <- read.csv("Flo_buds/input/Budburst_Datasheet2_2015-05-15.csv") # long format for consolidated treatments and chilling

###DBstoped here on 11/22/16####

# add relevant columns to d2 twigs

idx <- strsplit(as.character(d2$id), "_")
d2$site <- unlist(lapply(idx, function(x) x[2]))
d2$rep <- unlist(lapply(idx, function(x) x[3]))
d2$sp <- substr(unlist(lapply(idx, function(x) x[1])), 1, 6)
d2$gen <- substr(unlist(lapply(idx, function(x) x[1])), 1, 3)
d2$ind <- substr(d2$id, 1, 11)


d2$warm <- factor(substr(d2$treatcode, 1, 1), labels = c("cool", "warm"))
d2$photo <- factor(substr(d2$treatcode, 2, 2), labels = c("long", "short"))
d2$chill <- factor(substr(d2$treatcode, 3, 3), labels = c("chill0", "chill1", "chill2"))

head(d2)

coltokeep <- c("Date","id","sp","rep","site","ind","treatcode","warm","photo","chill","gen","Term.fl","Lat.fl","Term.lf","Lat.lf","Comments","Observer")

d <- rbind(d1[coltokeep], d2[coltokeep])


# Format date, making a continuous day since beginning of experiment. * For chill, this is from the first day after taken out of chilling! *
d$Date <- strptime(d$Date, "%Y-%m-%d")
day0 <- as.numeric(format(d$Date, "%j"))
# from min(d$Date)
d$day <- day0 - as.numeric(format(strptime("2015-02-06", "%Y-%m-%d"), "%j")) + 1 
# see min(d[d$chill=="chill1","Date"]), but actual initiation was March 11, see budburst protocol
d$day.chill <- day0 - as.numeric(format(strptime("2015-03-11", "%Y-%m-%d"), "%j")) + 1 

d$dayuse <- ifelse(d$chill == "chill0", d$day, d$day.chill)

# order by date

d <- d[order(d$Date, d$id, d$treatcode),]

# typical difference in date by treatment
for(i in levels(d$treatcode)){
  datediff <- diff(d[d$treatcode == i,"Date"])
  cat(rep("<>", 20), "\n", i, "\n")
  print(summary(unclass(datediff[datediff!=0]/60/60/24)))
}


# Cleanup: fix data types (slashes and other characters in the phenostage columns), date format

names(d) 

# make continuous data, now using second value if something is split by slash
d$tleaf <- unlist(lapply(strsplit(as.character(d$Term.lf), "/"), function(x) ifelse(length(x)>1, x[2], x[1])))
d$lleaf <- unlist(lapply(strsplit(as.character(d$Lat.lf), "/"), function(x) ifelse(length(x)>1, x[2], x[1])))

# and use first values if comma. This is a sequential manipulation, after slash data have been modified.
d$tleaf <- unlist(lapply(strsplit(as.character(d$tleaf), ", "), function(x) ifelse(length(x)>1, x[1], x[1])))
d$lleaf <- unlist(lapply(strsplit(as.character(d$lleaf), ", "), function(x) ifelse(length(x)>1, x[1], x[1])))

# finally, make non-numeric data into NA
for(i in c("tleaf","lleaf","Term.fl","Lat.fl")){
  d[,i][d[,i] =="-"] = NA
  d[,i][d[,i] ==""] = NA
  d[,i][d[,i] =="*"] = NA
}

d$lleaf <- sub("\\*", "", d$lleaf) # get rid of one asterix after 4*

# Make into numeric data, needed because it was read in with weird characters and automaticially made into factors
for(i in c("tleaf","lleaf","Term.fl","Lat.fl")){
  d[,i] = as.numeric(as.character(d[,i])) }

# calculating day since initiation of experiment, by twig id (includes treatment). Tricky part: what should NA be? They still haven't reached stage 6... for this calculation, I put them as 75.

# 

# For chill treatments, count days since they started in chambers, not since chill0 started
# now adding vector nl for 0 if non-leafout, 1 if leafout.

bday <- lday <- fday <- nl <- vector()

for(i in levels(d$id)){ # i=levels(d$id)[500] # for each individual clipping.
  
  dx <- d[d$id == i,]
  
  day.use <- ifelse(dx$chill[1] == "chill0", "day", "day.chill")
  
  # 1. for both terminal and lateral buds, what is the max stage within a row. Identify which rows are greater or equal to the specific BBCH stage
  # 2. now for that individual, find the earliest day at which that stage was reached.
  bdax <- which(apply(dx[,c("tleaf","lleaf")], 1, max, na.rm=T) >= 3)
  if(length(bdax) < 1) bdax = NA else bdax = dx[min(bdax),day.use]
  
  ldax <- which(apply(dx[,c("tleaf","lleaf")], 1, max, na.rm=T) >= 6)
  if(length(ldax) < 1) {ldax = NA; nl <- c(nl, 0)} else {ldax = dx[min(ldax),day.use]; nl <- c(nl, 1)}
  
  fdax <- which(apply(dx[,c("Term.fl","Lat.fl")], 1, max) > 16)
  if(length(fdax) < 1) fdax = NA else fdax = dx[min(fdax),day.use]
  
  bday <- c(bday, bdax)
  lday <- c(lday, ldax)
  fday <- c(fday, fdax)	
}

# merging with unique id data

dx <- d[match(levels(d$id), d$id),] # with twig id in same order as the loop above

dx <- dx[,2:ncol(dx)]

dx <- data.frame(dx, lday, fday, bday, nl)

# Clean up levels for the treatment factors. Default is alphabetical, here want to sort in a meaningful way.
# levels(dx$treatcode) <- c(2,1,4,3)
# dx$treatcode <- as.factor(dx$treatcode)
# levels(dx$treatcode) <- c("Cool-short","Cool-long","Warm-short","Warm-long")

dx$photo <- as.factor(as.character(dx$photo))
levels(dx$photo) <- c('12', '08')
dx$photo <- as.factor(as.character(dx$photo))

dx$warm <- as.factor(as.character(dx$warm))
levels(dx$warm) <- c('15', '20')
dx$warm <- as.factor(as.character(dx$warm))


## Check issue: were long-day individuals later leafing out than short-day individuals? No.

aggregate(dx["lday"], dx[c("site", "warm", "photo")], FUN=mean, na.rm=T) #can replace lday with bday etc.

head(dx)
######## Additional calcuations: 
# Calculating typical leafout day by species, across sites

setwd("~/Documents/git/buds/analyses")

dxx <- dx[dx$treatcode == "WL0",]

lday.agg <- aggregate(lday ~ sp, data = dxx, FUN = mean)
#do we have data for flowers too? (DB)
fday.agg <- aggregate(fday ~ sp, data = dxx, FUN = mean)
hist(fday.agg$fday)
#this seemed to work (DB)

lday.agg <- lday.agg[order(lday.agg$lday),]
#Repeat for flower
fday.agg <- fday.agg[order(fday.agg$fday),]

plot(lday.agg$lday,
     type = "n",
     main = "Typical Leafout Day in WL0",
     ylab = "Day")
text(1:nrow(lday.agg), lday.agg$lday, 
     labels = lday.agg$sp,
     cex = 0.5, col = "midnightblue")
#try for flowering
plot(fday.agg$fday,
     type = "n",
     main = "Typical Flowering Day in WL0",
     ylab = "Day")
text(1:nrow(fday.agg), fday.agg$fday, 
     labels = fday.agg$sp,
     cex = 0.5, col = "midnightblue")

#It seems that Dan F did recourd fday as first flowering day per indivudual, so maybe this is useful. This is where I stopped on 12/1/16
dev.print(device = pdf, file = "./graphs/Typical Leafout WL0.pdf", width = 10, height = 8)