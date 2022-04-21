import argparse
import json
import os
import glob
import pprint
import string
import subprocess
import sys
import re

parser = argparse.ArgumentParser(description='Sign binaries for Windows, macOS, and Linux')
parser.add_argument('path', help='Path to file for signing')
parser.add_argument('keycode', help='Platform-specific key code for signing')
parser.add_argument('opcode', help='Platform-specific operation code for signing')
# TODO: Make this more robust
parser.add_argument('--params', help='Parameters for signing')
args = parser.parse_args()

params = []
if args.params is not None:
	params = args.params.split(", ")

esrp_tool = os.path.join("esrp", "tools", "EsrpClient.exe")

aad_id = os.environ['AZURE_AAD_ID'].strip()
aad_id_temp = os.environ['AZURE_AAD_ID_TEMP'].strip()
workspace = os.environ['GITHUB_WORKSPACE'].strip()

source_location = os.path.dirname(args.path)
file_to_sign = os.path.basename(args.path)

auth_json = {
    "Version": "1.0.0",
    "AuthenticationType": "AAD_CERT",
    "TenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
    "ClientId": f"{aad_id}",
    "AuthCert": {
            "SubjectName": f"CN={aad_id_temp}.microsoft.com",
            "StoreLocation": "LocalMachine",
            "StoreName": "My"
    },
    "RequestSigningCert": {
            "SubjectName": f"CN={aad_id}",
            "StoreLocation": "LocalMachine",
            "StoreName": "My"
    }
}

input_json = {
	"Version": "1.0.0",
	"SignBatches": [
		{
			"SourceLocationType": "UNC",
			"SourceRootDirectory": source_location,
			"DestinationLocationType": "UNC",
			"DestinationRootDirectory": workspace,
			"SignRequestFiles": [
				{
					"CustomerCorrelationId": "01A7F55F-6CDD-4123-B255-77E6F212CDAD",
					"SourceLocation": file_to_sign,
					"DestinationLocation": os.path.join("signed", file_to_sign),
				}
			],
			"SigningInfo": {
				"Operations": [
					{
						"KeyCode": f"{args.keycode}",
						"OperationCode": f"{args.opcode}",
						"Parameters": {},
						"ToolName": "sign",
						"ToolVersion": "1.0",
					}
				]
			}
		}
	]
}

# add parameters to input.json (e.g. enabling the hardened runtime for macOS)
if len(params) > 0:
	i = 0
	while i < len(params):
		input_json["SignBatches"][0]["SigningInfo"]["Operations"][0]["Parameters"][params[i]] = params[i + 1]
		i += 2

policy_json = {
	"Version": "1.0.0",
	"Intent": "production release",
	"ContentType": "macOS payload",
}

configs = [
	("auth.json", auth_json),
	("input.json", input_json),
	("policy.json", policy_json),
]

for filename, data in configs:
	with open(filename, 'w') as fp:
		json.dump(data, fp)

# Run ESRP Client
esrp_out = "esrp_out.json"
result = subprocess.run(
	[esrp_tool, "sign",
	"-a", "auth.json",
	"-i", "input.json",
	"-p", "policy.json",
	"-o", esrp_out,
	"-l", "Verbose"],
	capture_output=True,
	text=True,
	cwd=workspace)

# Scrub log before printing
log = re.sub(r'^.+Uploading.*to\s*destinationUrl\s*(.+?),.+$',
    '***', 
    result.stdout,
    flags=re.IGNORECASE|re.MULTILINE)
print(log)

if result.returncode != 0:
	print("Failed to run ESRPClient.exe")
	sys.exit(1)

if os.path.isfile(esrp_out):
	print("ESRP output json:")
	with open(esrp_out, 'r') as fp:
		pprint.pp(json.load(fp))