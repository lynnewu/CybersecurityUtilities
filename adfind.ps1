$user=$args[0]
echo User:$user
get-aduser -filter 'name -like $user' -Properties Organization,Manager,Title

