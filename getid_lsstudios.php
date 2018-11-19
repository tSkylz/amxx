<?php 
if(!isset($_GET['key'])) die('Error: HTTPS://LSSTUDIOS.XYZ');

if(!isset($_GET['steamid'])) die('Error: HTTPS://LSSTUDIOS.XYZ');

function ConvertID($steamId)
{
    $iServer = '0';
    $iAuthID = '0';

    $szTmp = strtok($steamId, ':');

    while(($szTmp = strtok(':')) !== false) 
    {
        $szTmp2 = strtok(':');
        if($szTmp2 !== false)
        {
            $iServer = $szTmp; 
            $iAuthID = $szTmp2; 
        }
    }

    if($iAuthID == '0') 
        return '0'; 
  
    $steamId64 = bcmul($iAuthID, '2');
    $steamId64 = bcadd($steamId64, bcadd('76561197960265728', $iServer));  

    return $steamId64;
} 

$apikey = $_GET['key']; 
$steamid = ConvertID($_GET['steamid']);

$url = 'http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key='.$apikey.'&steamids='.$steamid.'&format=xml'; 

$separador1 = '@';
$separador2 = '>';
$separador3 = '*';
$separador4 = '<';

$xml = @simplexml_load_file($url) or die($errorMsg); 

$result1 = $xml->players->player->avatarfull; // Imagen de perfil.
$result2 = $xml->players->player->profileurl; // Url de perfil.
$result3 = $xml->players->player->loccountrycode; // Codigo de pais.
$result4 = $xml->players->player->personastate; // Status de perfil

echo $separador1,$result1,$separador2,$result2,$separador3,$result3,$separador4,$result4;
?>