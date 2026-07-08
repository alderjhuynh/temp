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

# --- Split / Double support -------------------------------------------------
# A "hand object" wraps one of the player's hands (there can be more than one
# once a split has happened) together with its own bet and state flags.

function New-HandObject {
    param([object[]]$Cards, [int]$Bet)
    $cardList = [System.Collections.ArrayList]::new()
    foreach ($c in $Cards) { [void]$cardList.Add([string]$c) }
    return [PSCustomObject]@{
        Cards     = $cardList
        Bet       = $Bet
        Doubled   = $false
        SplitAces = $false   # true if this hand came from splitting a pair of aces
        Done      = $false
        Result    = ''
        Payout    = 0
    }
}

function Test-CanSplit {
    # Real casino rule: only the original two cards, only if they share the
    # same rank, only if there's room for another matching bet, and only up
    # to a table-typical maximum of 4 hands from repeated splitting.
    param($Hand, [int]$Credits, [int]$HandCount, [int]$MaxHands = 4)
    if ($Hand.Cards.Count -ne 2) { return $false }
    if ($HandCount -ge $MaxHands) { return $false }
    if ($Credits -lt $Hand.Bet) { return $false }
    $rank0 = Get-CardRank -Card ([string]$Hand.Cards[0])
    $rank1 = Get-CardRank -Card ([string]$Hand.Cards[1])
    return ($rank0 -eq $rank1)
}

function Test-CanDouble {
    # Real casino rule: only on your first two cards, and split aces don't
    # get the option (they only ever receive the one forced card).
    param($Hand, [int]$Credits)
    if ($Hand.Cards.Count -ne 2) { return $false }
    if ($Hand.SplitAces) { return $false }
    if ($Credits -lt $Hand.Bet) { return $false }
    return $true
}

function Show-BlackjackTable {
    param(
        [int]$Credits,
        [object[]]$Hands,
        [int]$ActiveIndex = -1,
        [object[]]$Dealer,
        [string]$Message = '',
        [switch]$RevealDealer
    )

    $totalBet = 0
    foreach ($h in $Hands) { $totalBet += $h.Bet }

    Show-GameBanner -Credits $Credits -Bet $totalBet

    if ($RevealDealer) {
        Write-Host ('Dealer [{0}]' -f (Get-HandTotal -Hand $Dealer))
        Show-CardRow -Cards @($Dealer)
    } else {
        Write-Host ('Dealer [{0} + ?]' -f (Get-HandTotal -Hand @($Dealer[0])))
        Show-CardRow -Cards @($Dealer) -HideSecond
    }

    Write-Host ''

    for ($i = 0; $i -lt $Hands.Count; $i++) {
        $hand = $Hands[$i]
        if ($Hands.Count -gt 1) {
            $marker = if ($i -eq $ActiveIndex) { '  <-- playing' } else { '' }
            $tag = ''
            if ($hand.Doubled) { $tag = ' (doubled)' }
            if ($hand.SplitAces) { $tag = ' (split aces)' }
            Write-Host ('Hand {0} [{1}]  Bet: {2}{3}{4}' -f ($i + 1), (Get-HandTotal -Hand $hand.Cards), $hand.Bet, $tag, $marker)
        } else {
            Write-Host ('You [{0}]' -f (Get-HandTotal -Hand $hand.Cards))
        }
        Show-CardRow -Cards @($hand.Cards)
        Write-Host ''
    }

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
        $dealer = [System.Collections.ArrayList]::new()
        $firstCards = [System.Collections.ArrayList]::new()
        [void]$firstCards.Add((Draw-Card))
        [void]$dealer.Add((Draw-Card))
        [void]$firstCards.Add((Draw-Card))
        [void]$dealer.Add((Draw-Card))

        $hands = [System.Collections.ArrayList]::new()
        [void]$hands.Add((New-HandObject -Cards @($firstCards) -Bet $bet))

        $message = ''
        $roundQuit = $false

        if (Test-Blackjack -Hand $hands[0].Cards) {
            # A natural blackjack is settled immediately: no hitting, no
            # doubling, no splitting a hand that has already won.
            Show-BlackjackTable -Credits $credits -Hands $hands -Dealer $dealer -Message 'Blackjack.' -RevealDealer
            if (Test-Blackjack -Hand $dealer) {
                $hands[0].Payout = $hands[0].Bet
                $message = 'Push. Both sides have blackjack.'
            } else {
                $hands[0].Payout = ($hands[0].Bet * 2) + [math]::Floor($hands[0].Bet / 2)
                $message = ('Blackjack pays 3:2. +{0}' -f ($hands[0].Payout - $hands[0].Bet))
            }
        } else {
            # Play out every hand at the table, left to right. Splitting
            # inserts a new hand right after the one being played, so the
            # index-based loop naturally reaches it in turn.
            $idx = 0
            while ($idx -lt $hands.Count) {
                $hand = $hands[$idx]

                if ($hand.SplitAces) {
                    # Split aces: one card each, no further action. Matches
                    # standard physical-table rules.
                    $hand.Done = $true
                    $idx++
                    continue
                }

                while (-not $hand.Done) {
                    $total = Get-HandTotal -Hand $hand.Cards
                    if ($total -ge 21) {
                        $hand.Done = $true
                        break
                    }

                    $canSplit = Test-CanSplit -Hand $hand -Credits $credits -HandCount $hands.Count
                    $canDouble = Test-CanDouble -Hand $hand -Credits $credits

                    $prompt = '[h] hit   [s] stand'
                    if ($canDouble) { $prompt += '   [d] double' }
                    if ($canSplit) { $prompt += '   [p] split' }
                    $prompt += '   [q] quit game'

                    Show-BlackjackTable -Credits $credits -Hands $hands -ActiveIndex $idx -Dealer $dealer -Message $prompt
                    $turn = Read-Choice

                    switch ($turn) {
                        'h' {
                            [void]$hand.Cards.Add((Draw-Card))
                        }
                        's' {
                            $hand.Done = $true
                        }
                        'd' {
                            if ($canDouble) {
                                $credits -= $hand.Bet
                                $hand.Bet = $hand.Bet * 2
                                $hand.Doubled = $true
                                [void]$hand.Cards.Add((Draw-Card))
                                $hand.Done = $true
                            } else {
                                Write-Host 'Cannot double down right now.'
                                Read-Host 'Press Enter'
                            }
                        }
                        'p' {
                            if ($canSplit) {
                                $isAceSplit = ((Get-CardRank -Card ([string]$hand.Cards[0])) -eq 'A')
                                $secondCard = [string]$hand.Cards[1]

                                $credits -= $hand.Bet
                                $newBet = $hand.Bet

                                $hand.Cards.RemoveAt(1)
                                [void]$hand.Cards.Add((Draw-Card))

                                $newHand = New-HandObject -Cards @($secondCard) -Bet $newBet
                                [void]$newHand.Cards.Add((Draw-Card))

                                if ($isAceSplit) {
                                    $hand.SplitAces = $true
                                    $newHand.SplitAces = $true
                                    $hand.Done = $true
                                    $newHand.Done = $true
                                }

                                [void]$hands.Insert($idx + 1, $newHand)
                            } else {
                                Write-Host 'Cannot split right now.'
                                Read-Host 'Press Enter'
                            }
                        }
                        'q' {
                            $roundQuit = $true
                            $hand.Done = $true
                        }
                        default {
                            # Unrecognized input: redisplay and ask again.
                        }
                    }

                    if ($roundQuit) { break }
                }

                if ($roundQuit) { break }
                $idx++
            }

            if ($roundQuit) {
                $refund = 0
                foreach ($h in $hands) { $refund += $h.Bet }
                $credits += $refund
                break
            }

            $anyAlive = $false
            foreach ($h in $hands) {
                if ((Get-HandTotal -Hand $h.Cards) -le 21) { $anyAlive = $true }
            }
            if ($anyAlive) {
                while (Get-DealerShouldHit -Hand $dealer) {
                    [void]$dealer.Add((Draw-Card))
                }
            }

            Show-BlackjackTable -Credits $credits -Hands $hands -Dealer $dealer -RevealDealer
            $dealerTotal = Get-HandTotal -Hand $dealer

            foreach ($h in $hands) {
                $pTotal = Get-HandTotal -Hand $h.Cards
                if ($pTotal -gt 21) {
                    $h.Payout = 0
                    $h.Result = ('Bust (-{0})' -f $h.Bet)
                } elseif ($dealerTotal -gt 21 -or $pTotal -gt $dealerTotal) {
                    $h.Payout = $h.Bet * 2
                    $h.Result = ('Win (+{0})' -f $h.Bet)
                } elseif ($pTotal -eq $dealerTotal) {
                    $h.Payout = $h.Bet
                    $h.Result = 'Push'
                } else {
                    $h.Payout = 0
                    $h.Result = ('Lose (-{0})' -f $h.Bet)
                }
            }

            if ($hands.Count -gt 1) {
                $lines = @()
                for ($i = 0; $i -lt $hands.Count; $i++) {
                    $lines += ('Hand {0}: {1}' -f ($i + 1), $hands[$i].Result)
                }
                $message = $lines -join '   '
            } else {
                $message = $hands[0].Result
            }
        }

        $totalPayout = 0
        foreach ($h in $hands) { $totalPayout += $h.Payout }
        $credits += $totalPayout

        Write-Host ''
        Write-Host $message
        Read-Host 'Press Enter'
    }
}

Play-Blackjack
