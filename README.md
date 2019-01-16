# BAMCIS AWS Price List Module

A small module with some specific supplemental cmdlets for the AWS Price List API.

## Table of Contents
- [Usage](#usage)
- [Revision History](#revision-history)

## Usage

Import the module

    Import-Module -Name AWSPriceList

Execute a cmdlet

    Get-AWSPriceListServices

The `Get-AWSPriceListProductInformation` cmdlet is used to find specific SKUs inside the price list offer file for a product using a filter. The filter analyzes the key/value pairs of the product attributes object in the offer file json. If all of the filter key/values match the product attributes, that SKU and its attributes are included in the return value. For example:

    Get-AWSPriceListProductInformation -Product AmazonRDS -Filter @{"location" = "US East (N. Virginia)"; "instanceType" = "db.m4.large"; "databaseEngine" = "PostgreSQL"}

This finds the SKU for the db.m4.large PostgreSQL RDS instance in us-east-1. 

## Revision History

### 1.0.1
Fixed bug in the Url parameter for Get-AWSPriceListProductInformation.

### 1.0.0
Initial release of the module.