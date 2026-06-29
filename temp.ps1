Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------------
# REEL STOPPER
# A skill-based, non-gambling "slot machine" game.
# Three reels spin continuously. You stop them one at a time by hitting
# Enter at the right moment. Land matching symbols to build your streak
# and score. No money, no bets -- just timing and a high score to chase.
# ----------------------------------------------------------------------------

$script:Symbols = @('*', '#', '@', '+', '%', '$')
$script:SymbolNames = @{
    '*' = 'Star'
    '#' = 'Hash'
    '@' = 'Comet'
    '+' = 'Plus'
    '%' = 'Orb'
    '$' = 'Gem'
}
# Rarer symbols score higher. Lower weight = rarer.
$script:SymbolWeights = @{
    '*' = 30
    '#' = 25
    '@' = 20
    '+' = 15
    '%' = 8
    '$' = 2
}
$script:SymbolValue = @{
    '*' = 10
    '#' = 15
    '@' = 25
    '+' = 40
    '%' = 100
    '$' = 500
}

function Get-RepeatText {
    param([string]$Character, [int]$Count)
    if ($Count -le 0) { return '' }
    return ([string]$Character[0]) * $Count
}

function Get-BoxInnerWidth {
    param([int]$Width)
    if ($Width -lt 4) { return 1 }
    return $Width - 2
}

function Write-BoxLine {
    param([string]$Text = '', [int]$Width = 58)
    $innerWidth = Get-BoxInnerWidth -Width $Width
    $content = if ($null -eq $Text) { '' } else { [string]$Text }
    if ($content.Length -gt $innerWidth) { $content = $content.Substring(0, $innerWidth) }
    Write-Host ('|{0}|' -f $content.PadRight($innerWidth))
}

function Get-CenteredText {
    param([string]$Text, [int]$Width)
    $content = if ($null -eq $Text) { '' } else { [string]$Text }
    $innerWidth = Get-BoxInnerWidth -Width $Width
    if ($content.Length -ge $innerWidth) { return $content.Substring(0, $innerWidth) }
    $leftPad = [math]::Floor(($innerWidth - $content.Length) / 2)
    return (' ' * $leftPad) + $content
}

function Show-GameBanner {
    param([int]$Score, [int]$Streak = 0, [int]$Spins = 0, [int]$Width = 58)
    Clear-Host
    Write-Host ('+{0}+' -f (Get-RepeatText -Character '=' -Count (Get-BoxInnerWidth -Width $Width)))
    Write-BoxLine -Text (Get-CenteredText -Text 'REEL STOPPER' -Width $Width) -Width $Width
    Write-BoxLine -Text (Get-CenteredText -Text 'Aura Arcade' -Width $Width) -Width $Width
    Write-Host ('+{0}+' -f (Get-RepeatText -Character '-' -Count (Get-BoxInnerWidth -Width $Width)))
    Write-BoxLine -Text ('  Score: {0}   Streak: {1}   Spins: {2}' -f $Score, $Streak, $Spins) -Width $Width
    Write-Host ('+{0}+' -f (Get-RepeatText -Character '=' -Count (Get-BoxInnerWidth -Width $Width)))
    Write-Host ''
}

function Get-WeightedSymbol {
    $total = 0
    foreach ($s in $script:Symbols) { $total += $script:SymbolWeights[$s] }
    $roll = Get-Random -Minimum 0 -Maximum $total
    $acc = 0
    foreach ($s in $script:Symbols) {
        $acc += $script:SymbolWeights[$s]
        if ($roll -lt $acc) { return $s }
    }
    return $script:Symbols[0]
}

function Get-ReelStripLine {
    param([string[]]$Strip, [int]$Offset, [int]$VisibleCount = 9)
    $line = ''
    for ($i = 0; $i -lt $VisibleCount; $i++) {
        $idx = ($Offset + $i) % $Strip.Count
        $line += $Strip[$idx]
    }
    return $line
}

function New-ReelStrip {
    param([int]$Length = 24)
    $strip = New-Object string[] $Length
    for ($i = 0; $i -lt $Length; $i++) { $strip[$i] = Get-WeightedSymbol }
    return $strip
}

function Show-Reels {
    param(
        [string[][]]$Strips,
        [int[]]$Offsets,
        [bool[]]$Stopped,
        [int]$ActiveReel
    )
    # Center window position is index 4 of a 9-wide view (0-based)
    $centerIdx = 4
    $rows = @('', '', '')
    for ($r = 0; $r -lt 3; $r++) { $rows[$r] = '|' }

    for ($reelIdx = 0; $reelIdx -lt $Strips.Count; $reelIdx++) {
        $line = Get-ReelStripLine -Strip $Strips[$reelIdx] -Offset $Offsets[$reelIdx] -VisibleCount 9
        $chars = $line.ToCharArray()
        for ($r = 0; $r -lt 3; $r++) {
            # show a tiny 3-symbol vertical slice isn't needed; show single horizontal blur row per reel
        }
        $top    = [string]$chars[($centerIdx - 1 + 9) % 9]
        $mid    = [string]$chars[$centerIdx]
        $bottom = [string]$chars[($centerIdx + 1) % 9]

        $marker = if ($Stopped[$reelIdx]) { ' ' } elseif ($reelIdx -eq $ActiveReel) { '>' } else { ' ' }

        $rows[0] += ('  {0}  ' -f $top)
        $rows[1] += ('{0} {1} {0}' -f $marker, $mid)
        $rows[2] += ('  {0}  ' -f $bottom)
        if ($reelIdx -lt $Strips.Count - 1) {
            $rows[0] += '|'
            $rows[1] += '|'
            $rows[2] += '|'
        }
    }
    $rows[0] += '|'
    $rows[1] += '|'
    $rows[2] += '|'

    $width = $rows[1].Length
    Write-Host ('  +{0}+' -f (Get-RepeatText -Character '-' -Count ($width - 2)))
    foreach ($row in $rows) { Write-Host ('  {0}' -f $row) }
    Write-Host ('  +{0}+' -f (Get-RepeatText -Character '-' -Count ($width - 2)))
}

function Get-MiddleSymbols {
    param([string[][]]$Strips, [int[]]$Offsets)
    $centerIdx = 4
    $result = @()
    foreach ($i in 0..($Strips.Count - 1)) {
        $line = Get-ReelStripLine -Strip $Strips[$i] -Offset $Offsets[$i] -VisibleCount 9
        $result += [string]$line.ToCharArray()[$centerIdx]
    }
    return $result
}

function Score-Spin {
    param([string[]]$Faces, [int]$Streak)

    $a, $b, $c = $Faces[0], $Faces[1], $Faces[2]

    if ($a -eq $b -and $b -eq $c) {
        $base = $script:SymbolValue[$a] * 3
        $newStreak = $Streak + 1
        $bonus = [math]::Floor($base * (0.15 * $newStreak))
        return @{
            Points  = $base + $bonus
            Streak  = $newStreak
            Message = ('TRIPLE {0}! +{1} (streak bonus +{2})' -f $script:SymbolNames[$a], $base, $bonus)
            Hit     = $true
        }
    }
    elseif ($a -eq $b -or $b -eq $c -or $a -eq $c) {
        $matchSymbol = if ($a -eq $b) { $a } elseif ($b -eq $c) { $b } else { $a }
        $base = $script:SymbolValue[$matchSymbol]
        return @{
            Points  = $base
            Streak  = 0
            Message = ('Pair of {0}s. +{1}' -f $script:SymbolNames[$matchSymbol], $base)
            Hit     = $true
        }
    }
    else {
        return @{
            Points  = 0
            Streak  = 0
            Message = 'No match.'
            Hit     = $false
        }
    }
}

function Animate-ReelStop {
    param(
        [string[][]]$Strips,
        [ref]$Offsets,
        [bool[]]$Stopped,
        [int]$ReelToStop,
        [int]$Score,
        [int]$Streak,
        [int]$SpinCount
    )
    # Spin fast, then decelerate to a stop on the targeted reel.
    $totalTicks = Get-Random -Minimum 10 -Maximum 16
    for ($t = 0; $t -lt $totalTicks; $t++) {
        for ($i = 0; $i -lt $Offsets.Value.Count; $i++) {
            if (-not $Stopped[$i]) {
                $Offsets.Value[$i] = ($Offsets.Value[$i] + 1) % $Strips[$i].Count
            }
        }
        Show-GameBanner -Score $Score -Streak $Streak -Spins $SpinCount
        Show-Reels -Strips $Strips -Offsets $Offsets.Value -Stopped $Stopped -ActiveReel $ReelToStop
        Write-Host ''
        Write-Host '  Hit [Enter] to stop the next reel...'
        $delay = 30 + ($t * 6)
        Start-Sleep -Milliseconds $delay
    }
    $Stopped[$ReelToStop] = $true
}

function Show-PayTable {
    Write-Host ''
    Write-Host '  PAYTABLE (per symbol, triple pays x3 + streak bonus)'
    foreach ($s in $script:Symbols) {
        Write-Host ('    {0}  {1,-6} pair={2,-4} triple={3}' -f $s, $script:SymbolNames[$s], $script:SymbolValue[$s], ($script:SymbolValue[$s] * 3))
    }
    Write-Host ''
    Read-Host '  Press Enter to continue'
}

function Play-ReelStopper {
    $score = 0
    $streak = 0
    $spinCount = 0
    $highScore = 0

    while ($true) {
        Show-GameBanner -Score $score -Streak $streak -Spins $spinCount
        Write-Host ('High score this session: {0}' -f $highScore)
        Write-Host ''
        Write-Host '[Enter] spin   [p] paytable   [q] quit'
        $cmd = (Read-Host '> ').Trim().ToLowerInvariant()
        if ($cmd -eq 'q') { break }
        if ($cmd -eq 'p') { Show-PayTable; continue }

        $strips = @()
        for ($i = 0; $i -lt 3; $i++) { $strips += ,(New-ReelStrip -Length 24) }
        $offsets = @(0, 0, 0)
        $stopped = @($false, $false, $false)

        for ($reel = 0; $reel -lt 3; $reel++) {
            Show-GameBanner -Score $score -Streak $streak -Spins $spinCount
            Show-Reels -Strips $strips -Offsets $offsets -Stopped $stopped -ActiveReel $reel
            Write-Host ''
            Write-Host ('  Reel {0} of 3 -- press [Enter] when ready to lock it in!' -f ($reel + 1))
            Read-Host ''

            Animate-ReelStop -Strips $strips -Offsets ([ref]$offsets) -Stopped $stopped -ReelToStop $reel `
                -Score $score -Streak $streak -SpinCount $spinCount

            Show-GameBanner -Score $score -Streak $streak -Spins $spinCount
            Show-Reels -Strips $strips -Offsets $offsets -Stopped $stopped -ActiveReel -1
            Write-Host ''
            Write-Host ('  Reel {0} locked!' -f ($reel + 1))
            Start-Sleep -Milliseconds 400
        }

        $faces = Get-MiddleSymbols -Strips $strips -Offsets $offsets
        $result = Score-Spin -Faces $faces -Streak $streak
        $score += $result.Points
        $streak = $result.Streak
        $spinCount += 1
        if ($score -gt $highScore) { $highScore = $score }

        Show-GameBanner -Score $score -Streak $streak -Spins $spinCount
        Show-Reels -Strips $strips -Offsets $offsets -Stopped $stopped -ActiveReel -1
        Write-Host ''
        if ($result.Hit) {
            Write-Host ('  *** {0} ***' -f $result.Message)
        } else {
            Write-Host ('  {0}' -f $result.Message)
        }
        Write-Host ''
        Read-Host '  Press Enter to spin again'
    }

    Clear-Host
    Write-Host ''
    Write-Host ('Final score: {0}   Best this session: {1}   Total spins: {2}' -f $score, $highScore, $spinCount)
    Write-Host 'Thanks for playing Reel Stopper!'
    Write-Host ''
}

Play-ReelStopper
