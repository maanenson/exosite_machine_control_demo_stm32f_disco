# exosite_machine_control_demo_stm32f_disco
Demo Machine Control Solution for Exosite Murano using ST Micro STM32F746G Discovery Kit

Note that this is an early demo and little testing or documentation is provided.  
I apologize for this and am working on that.

# Use with mbed example project:
https://developer.mbed.org/users/maanenson/code/EXOSITE_DISCO-F746NG_MACHINE_DEMO/
Note: Uses device's MAC Address as unique identifier to activate with the system.
Make sure to change the Product ID definition when compiling for your board and your Murano Product.
When creating your Product in Murano, you can use the spec file included here: /product/product_spec_template.yaml.

# Use this solution template in Murano when creating a new Solution
Note: The script.js file has a hard-coded device identifier.  You'll want to change
this or you'll have to change in the text form field every time you load the web app page.

This solution is a single page web app, it does not have a concept of users or log-ins.  
It is meant to demonstrate interacting with a remote device with Murano Solution APIs.
