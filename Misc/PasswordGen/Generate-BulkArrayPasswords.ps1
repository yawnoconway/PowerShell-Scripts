while($true){
   Write-Host "Generating Passwords"
#  Create array of 5-letter words
$words = Get-Content ".\wordsForArray-Baretxt.txt"

#  Get length of words array
$wordCount = $words.Length

#  Generate some random numbers
$ranNum1 = Get-Random -Minimum 0 -Maximum $wordCount
$ranNum2 = Get-Random -Minimum 0 -Maximum $wordCount
$ranNum3 = Get-Random -Minimum 1000 -Maximum 9999

#  First random word with capitalization
$ranWord1 = $words[$ranNum1].ToLower()
$ranWord1 = $ranWord1.substring(0,1).toUpper()+$ranWord1.substring(1,4)

#  Second random word
$ranWord2 = $words[$ranNum2].ToLower()

#  Catenate to create new password
$newPwd = $ranWord1+$ranNUm3+$ranWord2

$newPwd
}