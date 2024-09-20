#!/bin/bash

# 1. 检查依赖
# 1.1 检查 curl 是否安装
if ! command -v curl &> /dev/null; then
    echo "curl is not installed. Please install it and try again."
    exit 1
fi
# 1.2 检查 wget 是否安装
if ! command -v wget &> /dev/null; then
    echo "wget is not installed. Please install it and try again."
    exit 1
fi

# 2. 检查参数
url=$1
password=$2
# 未提供 url 或 password
if [ -z "$url" ] || [ -z "$password" ]; then
    echo "Usage: $0 <url> <password>"
    exit 1
fi

# 3. 第一次请求，获得 sfcsrftoken、csrfmiddlewaretoken 和 token
echo "==================== Request 01 start ===================="
# 3.1 使用 curl 请求
response=$(curl -i -s $url)
# 3.2 使用正则 "Set-Cookie: sfcsrftoken=(.*);" 提取 sfcsrftoken
sfcsrftoken=$(echo "$response" | grep -oP 'Set-Cookie: sfcsrftoken=\K[^;]*')
# 3.3 使用正则 '<input type="hidden" name="csrfmiddlewaretoken" value="(.*)"' 提取 csrfmiddlewaretoken
csrfmiddlewaretoken=$(echo "$response" | grep -oP '<input type="hidden" name="csrfmiddlewaretoken" value="\K[^"]*')
# 3.4 使用正则 '<input type="hidden" name="token" value="(.*)"'
token=$(echo "$response" | grep -oP '<input type="hidden" name="token" value="\K[^"]*')
# 3.5 打印值
echo "sfcsrftoken: $sfcsrftoken"
echo "csrfmiddlewaretoken: $csrfmiddlewaretoken"
echo "token: $token"
echo "===================== Request 01 end ====================="
# 3.6 检查是否成功提取
if [ -z "$sfcsrftoken" ] || [ -z "$csrfmiddlewaretoken" ] || [ -z "$token" ]; then
    echo "Failed to extract tokens from the response."
    exit 1
fi

# 4. 发送 POST 请求以获得 sessionid
echo "==================== Request 02 start ===================="
# 4.1 请求体 data-raw 设置为 csrfmiddlewaretoken=$csrfmiddlewaretoken&token=$token&password=$password
data="csrfmiddlewaretoken=$csrfmiddlewaretoken&token=$token&password=$password"
# 请求头的 Cookie 设置为 sfcsrftoken=$sfcsrftoken
header_cookie="sfcsrftoken=$sfcsrftoken"
header_content_type="Content-Type: application/x-www-form-urlencoded"
header_referer="$url"
response=$(curl -i -s -X POST -H "Cookie: $header_cookie" -H "Referer: $header_referer" -d "$data" "$url")
# 4.2 使用正则 'sessionid=(.*);' 提取 sessionid
sessionid=$(echo "$response" | grep -oP 'Set-Cookie: sessionid=\K[^;]*')
# 4.3 打印值
echo "sessionid: $sessionid"
echo "===================== Request 02 end ====================="
# 4.4 检查是否成功提取
if [ -z "$sessionid" ]; then
    echo "Failed to extract sessionid from the response."
    echo "Maybe the password is incorrect. Please check and try again."
    exit 1
fi

# 5. 发送 GET 请求以获取实际的文件地址
echo "==================== Request 03 start ===================="
# 5.1 URL 需要添加参数 dl=1
if [[ "$url" == *"?dl="* ]]; then
    url="${url}&dl=1"
else
    url="${url}?dl=1"
fi
# 请求头的 Cookie 设置为 sfcsrftoken=$sfcsrftoken; sessionid=$sessionid
header_cookie="sfcsrftoken=$sfcsrftoken; sessionid=$sessionid"
header_referer="$url"
response=$(curl -i -s -H "Cookie: $header_cookie" -H "Referer: $header_referer" "$url")
# 5.2 使用正则 "Location: (.*)" 提取文件地址
file_url=$(echo "$response" | grep -oP 'Location: \K.*')
# 5.3 检查是否成功提取
echo "file_url: $file_url"
echo "===================== Request 03 end ====================="
# 5.4 检查是否成功提取
if [ -z "$file_url" ]; then
    echo "Failed to extract file URL from the response."
    exit 1
fi

# 6. 下载文件
echo "===================== Download start ====================="
# 6.1 获取文件名（用 / 分割，取最后一部分，不使用 basename）
filename=$(echo "$file_url" | awk -F/ '{print $NF}')
# 去除末尾的 \r
filename=$(echo "$filename" | tr -d '\r')
if [ -z "$filename" ]; then
    echo "Failed to extract filename from the file URL."
    exit 1
fi
echo "file_url: $file_url"
# 6.2 请求头的 Cookie 设置为 sfcsrftoken=$sfcsrftoken; sessionid=$sessionid
header_cookie="sfcsrftoken=$sfcsrftoken; sessionid=$sessionid"
# 使用 wget 下载文件
wget --header="Cookie: $header_cookie" "$file_url" -O "$filename"
# 6.3 检查下载是否成功
if [ $? -ne 0 ]; then
    echo "Failed to download the file."
    exit 1
fi
echo "====================== Download end ======================"