#!/bin/bash
set -e
VERSION=$1
REPO=sehraan/ota
API=https://api.github.com/repos/$REPO
OUT=$(ls -td ~/*/out/target/product/spes 2>/dev/null | head -1)
[ -z "$OUT" ] && { echo "No spes build found"; exit 1; }
ZIP=$(ls -t $OUT/*Infinity*.zip 2>/dev/null | head -1)
[ -z "$ZIP" ] && { echo "No Infinity zip in $OUT"; exit 1; }
NAME=$(basename "$ZIP")
SIZE=$(stat -c%s "$ZIP")
MD5=$(md5sum "$ZIP" | cut -d' ' -f1)
DATE=$(grep -m1 ro.build.date.utc $OUT/system/build.prop | cut -d= -f2)
URL="https://github.com/$REPO/releases/download/$VERSION/$NAME"
AUTH="Authorization: Bearer $GH_TOKEN"

curl -sS -X POST -H "$AUTH" $API/releases \
  -d "{\"tag_name\":\"$VERSION\",\"name\":\"InfinityX $VERSION spes\"}" -o /dev/null || true
REL_ID=$(curl -sS -H "$AUTH" $API/releases/tags/$VERSION | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])")

for AID in $(curl -sS -H "$AUTH" $API/releases/$REL_ID/assets | python3 -c "import sys,json;[print(a['id']) for a in json.load(sys.stdin) if a['name']=='$NAME']"); do
  curl -sS -X DELETE -H "$AUTH" $API/releases/assets/$AID
done
curl --fail -X POST -H "$AUTH" -H "Content-Type: application/zip" \
  --data-binary @"$ZIP" "https://uploads.github.com/repos/$REPO/releases/$REL_ID/assets?name=$NAME" -o /dev/null

rm -rf ~/ota && git clone https://sehraan:$GH_TOKEN@github.com/$REPO.git ~/ota
cd ~/ota
cat > spes.json <<EOF
{
	"response": [
		{
			"filename": "$NAME",
			"download": "$URL",
			"timestamp": $DATE,
			"md5": "$MD5",
			"size": $SIZE,
			"version": "$VERSION"
		}
	]
}
EOF
cp changelog.txt "${NAME%.zip}.txt"
git add . && git commit -m "spes $VERSION" && git push
