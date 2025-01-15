sudo su

yum update -y

yum install -y httpd

mkdir store-dir
cd store-dir

# Download the template ZIP file
#wget https://www. - have to replace with website zip file

# Unzip the downloaded file
#unzip folder.zip

cd ecommerce-html-template

mv * /var/www/html/

cd /var/www/html/

systemctl enable httpd
systemctl start httpd
