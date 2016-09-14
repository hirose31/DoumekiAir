# DoumekiAir

## Installation

setup as station mode

https://www.flashair-developers.com/ja/documents/tutorials/advanced/1/



```
cpanm Carton
cd server-api/
carton install
carton exec -- plackup -I lib -R lib --access-log /dev/null -p 5000 ./script/rainbow-api-server

```

