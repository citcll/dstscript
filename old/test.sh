for i in $(jq '.[]' test.json); do
    echo $i | jq '.name'
done
