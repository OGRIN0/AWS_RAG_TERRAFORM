sudo su

yum update -y

yum install -y httpd

mkdir store-dir
cd store-dir

# Download the template ZIP file
#wget https://www.free-css.com/as/do/e-store.zip - have to replace with website zip file

# Unzip the downloaded file
#unzip e-store.zip

cd ecommerce-html-template

mv * /var/www/html/

cd /var/www/html/

systemctl enable httpd
systemctl start httpd
