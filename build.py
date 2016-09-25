import argparse, os, subprocess

def build(virus, spec):
	'''
	run build for single dataset
	'''
	print '\n------------------------------\n'
	print 'Processing ', virus, 'with spec ', spec
	download_with_fauna(virus, spec)
	process_with_augur(virus, spec)

def download_with_fauna(virus, spec):
	'''
	download single dataset
	'''
	print 'Downloading with fauna'
	os.chdir('fauna')
	run = 'vdb/' + virus + '_download.py'
	db = 'vdb'
	fstem = virus
	call = map(str, [params.bin, run, '-db', db, '-v', virus, '--fstem', virus])
	print call
	subprocess.call(call)
	os.chdir('..')

def process_with_augur(virus, spec):
	'''
	process single dataset
	'''
	print 'Processing with augur'
	os.chdir('augur')
	run = virus + '/' + virus + '.py'
	call = map(str, [params.bin, run])
	print call
	subprocess.call(call)
	os.chdir('..')

if __name__=="__main__":
	parser = argparse.ArgumentParser(description = "download and process")
	parser.add_argument('--bin', type = str, default = "python")
	parser.add_argument('--virus', type = str, default = "zika")
	parser.add_argument('--spec', type = str, default = "")
	params = parser.parse_args()

	build(params.virus, params.spec)
