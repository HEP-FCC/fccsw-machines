#!/bin/sh

cd "$(dirname "$0")"

rsync -aP index.php lxplus:/eos/project/f/fccsw-web/www/fccsw-machines/
rsync -aP bootstrap lxplus:/eos/project/f/fccsw-web/www/fccsw-machines/
