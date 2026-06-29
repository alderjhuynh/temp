Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:RankMap = @{
    '2' = 2; '3' = 3; '4' = 4; '5' = 5; '6' = 6; '7' = 7; '8' = 8; '9' = 9; '10' = 10
    'J' = 11; 'Q' = 12; 'K' = 13; 'A' = 14
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
    param([int]$Credits, [int]$Bet = 0, [int]$Width = 58)
    Clear-Host
    Write-Host ('+{0}+' -f (Get-RepeatText -Character '=' -Count (Get-BoxInnerWidth -Width $Width)))
    Write-BoxLine -Text (Get-CenteredText -Text 'BLACKJACK' -Width $Width) -Width $Width
    Write-BoxLine -Text (Get-CenteredText -Text 'Aura Gambling Suite' -Width $Width) -Width $Width
    Write-Host ('+{0}+' -f (Get-RepeatText -Character '-' -Count (Get-BoxInnerWidth -Width $Width)))
    if ($Bet -gt 0) {
        Write-BoxLine -Text ('  Credits: {0}   Bet: {1}' -f $Credits, $Bet) -Width $Width
    } else {
        Write-BoxLine -Text ('  Credits: {0}' -f $Credits) -Width $Width
    }
    Write-Host ('+{0}+' -f (Get-RepeatText -Character '=' -Count (Get-BoxInnerWidth -Width $Width)))
    Write-Host ''
}

function Read-Bet {
    param([int]$CurrentBet, [int]$Credits, [int]$Minimum = 10, [int]$Maximum = 500)
    $maxBet = [math]::Min($Credits, $Maximum)
    if ($maxBet -lt $Minimum) { $maxBet = $Minimum }
    $raw = Read-Host ("Enter bet ({0}-{1})" -f $Minimum, $maxBet)
    $parsed = 0
    if ([int]::TryParse($raw, [ref]$parsed)) {
        if ($parsed -lt $Minimum) { $parsed = $Minimum }
        if ($parsed -gt $maxBet) { $parsed = $maxBet }
        return $parsed
    }
    return $CurrentBet
}

function Read-Choice {
    param([string]$Prompt = '> ')
    $value = Read-Host $Prompt
    if ($null -eq $value) { return '' }
    return $value.Trim().ToLowerInvariant()
}

function New-ShuffledDeck {
    $cards = @()
    foreach ($suit in @('S', 'H', 'D', 'C')) {
        foreach ($rank in @('A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K')) {
            $cards += ('{0}|{1}' -f $rank, $suit)
        }
    }
    $shuffled = [System.Collections.Queue]::new()
    foreach ($card in (Get-Random -InputObject $cards -Count $cards.Count)) {
        [void]$shuffled.Enqueue($card)
    }
    return ,$shuffled
}

function Draw-Card {
    if ($script:CurrentDeck.Count -le 0) { throw 'Cannot draw from an empty deck.' }
    return $script:CurrentDeck.Dequeue()
}

function Get-CardRank {
    param([string]$Card)
    if ([string]::IsNullOrWhiteSpace($Card)) { return '' }
    return ($Card -split '\|', 2)[0]
}

function Get-CardSuit {
    param([string]$Card)
    if ([string]::IsNullOrWhiteSpace($Card)) { return '' }
    $parts = $Card -split '\|', 2
    if ($parts.Count -lt 2) { return '' }
    return $parts[1]
}

function Get-CardLines {
    param([string]$Card, [switch]$Hidden)
    if ($Hidden) {
        return @('.-----.', '|#####|', '|#####|', '|#####|', "'-----'")
    }
    $rank = Get-CardRank -Card $Card
    $suit = Get-CardSuit -Card $Card
    $left  = '{0,-2}' -f $rank
    $right = '{0,2}' -f $rank
    return @(
        '.-----.',
        ('|{0}   |' -f $left),
        ('|  {0}  |' -f $suit),
        ('|   {0}|' -f $right),
        "'-----'"
    )
}

function Show-CardRow {
    param([string[]]$Cards, [switch]$HideSecond)
    if ($null -eq $Cards -or $Cards.Count -eq 0) { return }
    $rows = @('', '', '', '', '')
    for ($i = 0; $i -lt $Cards.Count; $i++) {
        $lines = Get-CardLines -Card $Cards[$i] -Hidden:($HideSecond -and $i -eq 1)
        for ($row = 0; $row -lt $rows.Count; $row++) {
            if ($rows[$row]) { $rows[$row] += ' ' }
            $rows[$row] += $lines[$row]
        }
    }
    foreach ($row in $rows) { Write-Host ('  {0}' -f $row) }
}

function Get-HandInfo {
    param([object[]]$Hand)
    $total = 0
    $aces = 0
    foreach ($card in $Hand) {
        $rank = Get-CardRank -Card ([string]$card)
        switch ($rank) {
            'J' { $total += 10 }
            'Q' { $total += 10 }
            'K' { $total += 10 }
            'A' { $total += 11; $aces += 1 }
            default { $total += [int]$rank }
        }
    }
    while ($total -gt 21 -and $aces -gt 0) { $total -= 10; $aces -= 1 }
    return @{ Total = $total; Soft = ($aces -gt 0) }
}

function Get-HandTotal {
    param([object[]]$Hand)
    return (Get-HandInfo -Hand $Hand).Total
}

function Test-Blackjack {
    param([object[]]$Hand)
    return ($Hand.Count -eq 2 -and (Get-HandTotal -Hand $Hand) -eq 21)
}

function Get-DealerShouldHit {
    param([object[]]$Hand)
    $info = Get-HandInfo -Hand $Hand
    if ($info.Total -lt 17) { return $true }
    if ($info.Total -eq 17 -and $info.Soft) { return $true }
    return $false
}

function Show-BlackjackTable {
    param(
        [int]$Credits,
        [int]$Bet,
        [object[]]$Player,
        [object[]]$Dealer,
        [string]$Message = '',
        [switch]$RevealDealer
    )

    Show-GameBanner -Credits $Credits -Bet $Bet

    if ($RevealDealer) {
        Write-Host ('Dealer [{0}]' -f (Get-HandTotal -Hand $Dealer))
        Show-CardRow -Cards @($Dealer)
    } else {
        Write-Host ('Dealer [{0} + ?]' -f (Get-HandTotal -Hand @($Dealer[0])))
        Show-CardRow -Cards @($Dealer) -HideSecond
    }

    Write-Host ''
    Write-Host ('You [{0}]' -f (Get-HandTotal -Hand $Player))
    Show-CardRow -Cards @($Player)
    Write-Host ''

    if ($Message) {
        Write-Host $Message
        Write-Host ''
    }
}

function Play-Blackjack {
    $credits = 100
    $bet = 10

    while ($true) {
        Show-GameBanner -Credits $credits -Bet $bet

        if ($credits -le 0) {
            Write-Host 'OUT OF CREDITS.'
            $answer = Read-Choice '[q] quit, [r] reset credits'
            if ($answer -eq 'q') { break }
            if ($answer -eq 'r') { $credits = 100 }
            continue
        }

        Write-Host ('[Enter] deal   [b] change bet ({0})   [q] quit' -f $bet)
        $choice = Read-Choice
        if ($choice -eq 'q') { break }
        if ($choice -eq 'b') {
            $bet = Read-Bet -CurrentBet $bet -Credits $credits -Minimum 10 -Maximum 500
            continue
        }

        if ($bet -gt $credits) {
            Write-Host ''
            Write-Host 'Not enough credits.'
            Read-Host 'Press Enter'
            continue
        }

        $credits -= $bet

        $script:CurrentDeck = New-ShuffledDeck
        $player = [System.Collections.ArrayList]::new()
        $dealer = [System.Collections.ArrayList]::new()
        [void]$player.Add((Draw-Card))
        [void]$dealer.Add((Draw-Card))
        [void]$player.Add((Draw-Card))
        [void]$dealer.Add((Draw-Card))

        $payout = 0
        $message = ''

        if (Test-Blackjack -Hand $player) {
            Show-BlackjackTable -Credits $credits -Bet $bet -Player $player -Dealer $dealer -Message 'Blackjack.' -RevealDealer
            if (Test-Blackjack -Hand $dealer) {
                $payout = $bet
                $message = 'Push. Both sides have blackjack.'
            } else {
                $payout = ($bet * 2) + [math]::Floor($bet / 2)
                $message = ('Blackjack pays 3:2. +{0}' -f ($payout - $bet))
            }
        } else {
            $roundQuit = $false
            while ($true) {
                $playerTotal = Get-HandTotal -Hand $player
                if ($playerTotal -gt 21) {
                    Show-BlackjackTable -Credits $credits -Bet $bet -Player $player -Dealer $dealer -Message 'Bust.'
                    $payout = 0
                    $message = ('Bust. -{0}' -f $bet)
                    break
                }
                if ($playerTotal -eq 21) { break }

                Show-BlackjackTable -Credits $credits -Bet $bet -Player $player -Dealer $dealer -Message '[h] hit   [s] stand   [q] quit game'
                $turn = Read-Choice
                switch ($turn) {
                    'h' { [void]$player.Add((Draw-Card)) }
                    'q' { $roundQuit = $true; break }
                    default { break }
                }
                if ($turn -ne 'h') { break }
            }

            if ($roundQuit) {
                $credits += $bet
                break
            }

            if ((Get-HandTotal -Hand $player) -le 21 -and $message -eq '') {
                while (Get-DealerShouldHit -Hand $dealer) {
                    [void]$dealer.Add((Draw-Card))
                }

                Show-BlackjackTable -Credits $credits -Bet $bet -Player $player -Dealer $dealer -RevealDealer
                $playerTotal = Get-HandTotal -Hand $player
                $dealerTotal = Get-HandTotal -Hand $dealer

                if ($dealerTotal -gt 21 -or $playerTotal -gt $dealerTotal) {
                    $payout = $bet * 2
                    $message = ('You win. +{0}' -f $bet)
                } elseif ($playerTotal -eq $dealerTotal) {
                    $payout = $bet
                    $message = 'Push.'
                } else {
                    $payout = 0
                    $message = ('Dealer wins. -{0}' -f $bet)
                }
            }
        }

        $credits += $payout
        Write-Host ''
        Write-Host $message
        Read-Host 'Press Enter'
    }
}

Play-Blackjackp
