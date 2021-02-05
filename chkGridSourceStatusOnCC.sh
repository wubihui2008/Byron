#!/bin/bash
appKey="3ddac08a943fe2fb4567c2efe497abbf"
appsecret="8a92cb952583377cb191b8b48df55e9a"
signature=
requestId=
timestamp=

function getRequestId()
{
	requestId=$(head -10 /dev/urandom |cksum |md5sum | cut -d " " -f1)
}

function getSignature()
{
	timestamp=$(date +%s)
	signature=$(echo -n "$appKey$timestamp" | md5sum |cut -d " " -f1)
}

getRequestId
echo $requestId
getSignature
echo $signature
