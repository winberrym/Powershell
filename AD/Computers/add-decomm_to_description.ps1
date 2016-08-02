# Written by: Matt Winberry
# Function: Script to add the word decomm to the beginning of the AD Computer Description.
# I run this as a scheduled task on a server that has the AD PS Module installed.
#
# Creation date: 4/28/16
# Last modified date: 4/28/2016
# Version 1
# Add major updates below this line!
#
#

$decomm = get-adcomputer -Filter * -Property Description -Searchbase "OU=Decomm Servers,OU=Go,OU=Here,DC=domain,DC=org"
foreach($server in $decomm)
{
    if($server.description -like "*decomm*")
    {
    }
    else
    {
        if($server.Description)
        {
            $sdesc = $server.description.insert(0,'decomm - ')
            $server.description = $sdesc
            set-adcomputer -Instance $server
        }
        else
        {
            $sdesc = "decomm"
            $server.description = $sdesc
            set-adcomputer -Instance $server
        }
    }
}