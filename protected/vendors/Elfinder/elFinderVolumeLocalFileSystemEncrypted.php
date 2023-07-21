<?php

class elFinderVolumeLocalFileSystemEncrypted extends elFinderVolumeLocalFileSystem
{
	protected $driverId = 'le';
	
	protected function _save($fp, $dir, $name, $mime, $w, $h) {
		
		if (!Yii::app()->crypt) {
			return $this->setError('Cryptor not found');
		}
		
		$path = $dir.DIRECTORY_SEPARATOR.$name;

		if (!($target = @fopen($path, 'wb'))) {
			return false;
		}

		while (!feof($fp)) {
			fwrite($target, Yii::app()->crypt->encrypt(fread($fp, 8192)));
		}
		fclose($target);
		@chmod($path, $this->options['fileMode']);
		clearstatcache();
		return $path;
	}
	
	protected function _getContents($path) {
		return Yii::app()->crypt->decrypt(file_get_contents($path));
	}
	
	/**
	 * Write a string to a file
	 *
	 * @param  string  $path     file path
	 * @param  string  $content  new file content
	 * @return bool
	 * @author Dmitry (dio) Levashov
	 **/
	protected function _filePutContents($path, $content) {
		if (@file_put_contents($path, Yii::app()->crypt->encrypt($content), LOCK_EX) !== false) {
			clearstatcache();
			return true;
		}
		return false;
	}
}
?>
