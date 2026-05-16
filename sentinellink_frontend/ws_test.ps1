$messages = New-Object System.Collections.Generic.List[string]
try {
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $ct = New-Object System.Threading.CancellationTokenSource
    $connTask = $ws.ConnectAsync("ws://localhost:8080/ws", $ct.Token)
    $connTask.Wait(10000)
    
    $loginMsg = '{"type":"LOGIN_REQUEST","payload":{"username":"admin","password":"admin123"}}'
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($loginMsg)
    $segment = New-Object ArraySegment[byte] -ArgumentList @(,$buffer)
    $sendTask = $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct.Token)
    $sendTask.Wait(5000)

    $endTime = (Get-Date).AddSeconds(15)
    $recvBuffer = New-Object byte[] 8192
    
    while ((Get-Date) -lt $endTime -and $ws.State -eq 'Open') {
        $recvSegment = New-Object ArraySegment[byte] -ArgumentList @(,$recvBuffer)
        $recvTask = $ws.ReceiveAsync($recvSegment, $ct.Token)
        if ($recvTask.Wait(3000)) {
            $res = $recvTask.Result
            if ($res.Count -gt 0) {
                $msg = [System.Text.Encoding]::UTF8.GetString($recvBuffer, 0, $res.Count)
                Write-Host "MSG: $msg"
            }
        }
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
if ($ws.State -eq 'Open') { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Done", $ct.Token).Wait() }
