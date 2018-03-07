#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No files have been specified!")
inputMSMSparam<-NA
realName<-NA
outputCSV<-NA
tryOffline=F
PPMOverwrite<-NA
DatabaseOverwrite<-NA
IonizationOverwrite<-NA
siriusPath<-"/usr/local/bin/CSI/bin/sirius"
library(tools)
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  
  if(argCase=="realName")
  {
    realName=as.character(value)
  }
  if(argCase=="input")
  {
    inputMSMSparam=as.character(value)
  }
  if(argCase=="tryOffline")
  {
    tryOffline=as.logical(value)
  }
  if(argCase=="ppm")
  {
    PPMOverwrite=as.numeric(value)
  }
  if(argCase=="database")
  {
    DatabaseOverwrite=as.character(value)
  }
  if(argCase=="ionization")
  {
    IonizationOverwrite=as.character(value)
  }
  if(argCase=="output")
  {
    outputCSV=as.character(value)
  }
  
}



tmpdir<-paste(tempdir(),"/",sep="")

setwd(tmpdir)


cat("Loading ",inputMSMSparam,"\n")

MSMSparams<-readLines(inputMSMSparam)


splitParams<-strsplit(MSMSparams,split = " ",fixed = T)

database=""
ppm<-NA

databaseIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "MetFragDatabaseType",fixed=T)})
database<-tolower(strsplit(splitParams[[1]][[databaseIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(DatabaseOverwrite))
  database<-tolower(DatabaseOverwrite)
cat("Database is set to \"",database,"\"\n")
if(database=="localcsv")
  stop("Local database is not supported yet! use any of the following: all, pubchem, bio, kegg, hmdb")

ppmIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "DatabaseSearchRelativeMassDeviation",fixed=T)})
ppm<-as.numeric(strsplit(splitParams[[1]][[ppmIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(PPMOverwrite))
  ppm<-as.numeric(PPMOverwrite)
cat("ppm is set to \"",ppm,"\"\n")
if(is.null(ppm) | is.na(ppm))
  stop("Peak relative mass deviation is not defined!")

#### create MS file
compound<-basename(inputMSMSparam)
parentmass<-as.numeric(strsplit(compound,split = "_",fixed = T)[[1]][3])
cat("Parent mass is set to \"",parentmass,"\"\n")
if(is.null(parentmass) | is.na(parentmass))
  stop("Parent mass is not defined!")


ionization<-""
ionizationIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "PrecursorIonType",fixed=T)})
ionization<-as.character(strsplit(splitParams[[1]][[ionizationIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(PPMOverwrite))
  IonizationOverwrite<-as.character(IonizationOverwrite)

cat("Ionization mass is set to \"",ionization,"\"\n")
if(is.na(ionization) | is.null(ionization) | ionization=="")
  stop("ionization is not defined!")


collision<-""
collisionIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "PeakListString",fixed=T)})
collision<-as.character(strsplit(splitParams[[1]][[collisionIndex]],split = "=",fixed=T)[[1]][[2]])
collision<-gsub(pattern = "_",replacement = " ",x = collision,fixed=T)
collision<-gsub(pattern = ";",replacement = "\n",x = collision,fixed=T)
cat("Extracting MS2 information ...\n")
if(is.na(collision) | is.null(collision) | collision=="")
  stop("MS2 ions have not been not found!")
cat("Creating MS file ...\n")
toCSI<-paste(">compound ",compound,"\n",
             ">parentmass ",parentmass,"\n",
             ">ionization ",ionization,"\n\n",
             ">collision ",collision,"\n",sep = "")

writeLines(toCSI,"toCSI.ms")

inpitToCSIFile<-file_path_as_absolute("toCSI.ms")
print(inpitToCSIFile)

outputFolder<-paste(getwd(),"/outputTMP1",sep="")


toCSICommand<-paste(siriusPath," --database ", database,
                    " --fingerid --ppm-max ",ppm," --output ",outputFolder," ",inpitToCSIFile," 2>&1",sep="")


cat("Running CSI using", toCSICommand, "\n")

unlink(recursive = T,x = outputFolder)
t1<-try(system(command = toCSICommand,intern=T))

if(any(grepl("remove the database flags -d or --database because database",t1)) & tryOffline==T)
{
  cat("Online database is not available now! Trying offline mode!\n")
  unlink(recursive = T,x = outputFolder)
  toCSICommand<-paste(siriusPath,
                      " --fingerid --ppm-max ",ppm," --output ",outputFolder," ",inpitToCSIFile," 2>&1",sep="")
cat("Running CSI using", toCSICommand, "\n")
  t1 <- try(system(toCSICommand,intern = T))
}

if(any(grepl("just do not use any chemical database and omit the --fingerid option",t1)) & tryOffline==T)
{
  cat("FingerID is not available now! Trying offline mode without database!\n")
  unlink(recursive = T,x = outputFolder)
  toCSICommand<-paste(siriusPath,
                      " --ppm-max ",ppm," --output ",outputFolder," ",inpitToCSIFile," 2>&1",sep="")
cat("Running CSI using", toCSICommand, "\n")
  t1 <- try(system(toCSICommand,intern = T))
}


if(!is.null(attr(t1,which = "status")) && attr(t1,which = "status")==1){
  cat("::: Error :::\n")
  stop(t1)
}

cat("CSI finished! Trying to load the results ...\n")
requiredOutput<-(paste(list.dirs(outputFolder,recursive = F),"/","summary_csi_fingerid.csv",sep = ""))
if(file.exists(requiredOutput))
{
  tmpData<-read.table(requiredOutput,header = T,sep = "\t",quote = "",check.names = F,stringsAsFactors = F,comment.char = "")
  if(nrow(tmpData)!=0)
  {
    tmpData[tmpData$name=="\"\"","name"]<-"NONAME"
    parentRT<-as.numeric(strsplit(compound,split = "_",fixed = T)[[1]][2])
    parentFile<-(strsplit(compound,split = "_",fixed = T)[[1]][4])
    
    if(parentFile==".txt")
    {
      parentFile<-"NotFound"
    }else{
      parentFile<-gsub(pattern = ".txt",replacement = "",x = parentFile,fixed = T)
    }
    cat("Setting headers required for downstream ...\n")
    tmpData<-data.frame(fileName=parentFile,parentMZ=parentmass,parentRT=parentRT,tmpData)
    tmpData<-cbind(data.frame(Name=tmpData[,"name"],
                              "Identifier"=paste("Metabolite_",1:nrow(tmpData),sep=""),
                              "InChI"=tmpData[,"inchi"]),tmpData)
    cat("Writing the results ...\n")
    write.csv(x = tmpData,file = outputCSV)
    cat("Done!\n")
  }else{
    cat("Empty results! Nothing will be output!\n")
  }
  
}else{
  cat("Empty results! Nothing will be written out!\n")
}

