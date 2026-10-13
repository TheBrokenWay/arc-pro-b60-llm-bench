# Starts llama-server detached (WMI create returns at once, so the caller never waits on the server).
# Args: -Model <path> -Dev <Vulkan0|Vulkan1> -Label <run label> [-Extra "<more llama-server args>"]
param([string]$Model, [string]$Dev, [string]$Label, [string]$Extra = "")
$dir = "E:\LLM\bench\results\$Label"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
$exe = "E:\LLM\tools\llama_b11588\bin\llama-server.exe"
$srvargs = "-m `"$Model`" --host 127.0.0.1 --port 8080 -c 16384 -ngl 99 -dev $Dev $Extra"
$cmd = "cmd.exe /c `"`"$exe`" $srvargs 1>`"$dir\server.out`" 2>`"$dir\server.log`"`""
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd }
"create returned $($r.ReturnValue)"
