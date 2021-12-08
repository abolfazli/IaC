<!-- GETTING STARTED -->

### Disclaimer
This code is still under development. Do not use it for production purposes. The idea behind this automated code is to bring up an easy LAB to start Palo alto firewall configuration practices.

### Prerequisites
1. Having a Gmail account :-)
2. activating your free tier GCP account: https://console.cloud.google.com

##### Note: with 3 months free GCP you have 300 USD credit. The estimated hourly cost is 2 USD which means you can run this LAB for about 150 hours. GCP will not overcharge you as other Public vendors do. this is why it is chosen for training LABs.

<!-- USAGE -->
### Usage
1. go to: https://console.cloud.google.com
2. select your project if it's not selected.
3. Click on "Activate Cloud Shell"
4. run the following commands:
```
git clone https://github.com/abolfazli/IaC
cd Iac/paloalto-fw-basic-lab
chmod +x start.sh
sh start.sh
```
Have a coffee for 10 minutes and your LAB will be ready


##### Note: 
You can clean up all resources created by terraform with the following command:
```
terraform destroy
```
<p align="right">(<a href="#top">back to top</a>)</p>


<!-- CONTACT -->
### Contact
Ping me on Linkedin: [Amir Abolfazli Linkedin Page](https://www.linkedin.com/in/amirabolfazli/)

My GitHub link: [https://github.com/abolfazli](https://github.com/abolfazli)



<!-- ACKNOWLEDGMENTS -->
### Acknowledgments
Some useful linked to dig more:
* [PAN-OS® Administrator’s Guide](https://docs.paloaltonetworks.com/pan-os/10-1/pan-os-admin.html)
* [Google Cloud documentation](https://cloud.google.com/docs/)
* [Terraform Google Cloud Platform Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
* [Terraform Palo Alto Networks Provider](https://registry.terraform.io/providers/PaloAltoNetworks/panos/latest/docs)
<p align="right">(<a href="#top">back to top</a>)</p>


### LICENSE
Please see [LICENSE.txt](LICENSE.txt)
