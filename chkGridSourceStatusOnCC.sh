#!/bin/bash
requestURL="http://10.12.128.228/ccp/tvucc-device/openapi/3.0/device/listDevice"
appKey="3ddac08a943fe2fb4567c2efe497abbf"
appsecret="8a92cb952583377cb191b8b48df55e9a"
signature=
requestId=
timestamp=
devicePids=(38fc852a5f1f94a70000000000000001 38fc852a5f1f94a70000000000000002 cea55ff99b50bfb00000000000000001 cea55ff99b50bfb00000000000000002)
deviceCounts=
deviceStatus=(1 3 1 1)
postBody=
tmpFile="tmpFile.txt"
logFile="$0.log"
chkInterval=10

function getRequestId()
{
	requestId=$(head -10 /dev/urandom |cksum |md5sum | cut -d " " -f1)
}

function getSignature()
{
	timestamp=$(date +%s)
	signature=$(echo -n "${appsecret}$timestamp" | md5sum |cut -d " " -f1)
}

function getPostBody()
{
	postBody="{\"peerIds\":["
	deviceCounts=${#devicePids[@]}
	
	for((i=1;i<=deviceCounts;i++))
	do
		postBody="${postBody}\"${devicePids[$i-1]}\""
		if [ $i -lt $deviceCounts ] ;then
			postBody="${postBody},"
		fi
		
	done
	postBody="${postBody}]}"
}

function sendRequest()
{
	getRequestId
	getSignature
	getPostBody
	header1="Content-Type: application/json"
	header2="accessKey: {\"appkey\":\"$appKey\",\"timestamp\":\"$timestamp\",\"signature\":\"$signature\",\"requestId\":\"$requestId\"}"
	curl -s -H "$header1" -H "$header2" -d "$postBody" -X POST $requestURL | grep -io "{\"id\"[0-9a-z:\",_]\{10,\}" > $tmpFile 2>&1
}

function analyseReponse()
{
	if [ -s $tmpFile ] ;then
		for((i=0;i<deviceCounts;i++))
		do
			expectedStatus=${deviceStatus[$i]}
			pid=${devicePids[$i]}
			actualStatus=$(grep -i "$pid" $tmpFile | grep -io "status\":\"[0-9]" | cut -d "\"" -f3)
			if [ $actualStatus -eq $expectedStatus ] ;then
				echo "`date` Status of $pid is correct" >> $logFile
			else
				echo "`date` Status of $pid is incorrect!!!Expected:$expectedStatus   Actual:$actualStatus" >> $logFile
			fi
		done
		
		echo -e "\n\n" >> $logFile
	else
		echo "`date` Fail to get datafrom API" >> $logFile
	fi
			
}

function chkStatus()
{
	echo "Test log is written to $logFile"
	while :
	do
		sendRequest	
		analyseReponse
		sleep $chkInterval
	done
	
}

chkStatus

