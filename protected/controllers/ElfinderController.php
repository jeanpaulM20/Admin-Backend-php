<?php

define('ELFINDER_DROPBOX_CONSUMERKEY', 'zh49rt9rb77gn77');
define('ELFINDER_DROPBOX_CONSUMERSECRET', 'j4qj8ek1dafdzk8');

spl_autoload_unregister(array('YiiBase','autoload'));
Yii::import('application.vendors.Elfinder.Dropbox.autoload', true);
spl_autoload_register(array('YiiBase','autoload'));

Yii::import('application.vendors.Elfinder.*');
Yii::import('application.vendors.*');
require_once 'Zend/Oauth/Consumer.php';

class ElfinderController extends Controller
{

	protected $_filePath = 'media/files';
	protected $_encryptedPath = 'media/encrypted';

	public function filters()
	{
		return array(
			'accessControl', 
			array(
				'ApiAccessFilter',
				'restricted_urls' => array(
					//'elfinder/getEncrypted',
				)
			),
		);
	}

	public function accessRules()
	{
		return array(
			array('allow',
				'users' => array('@'),
			),
			/*array('allow',
				'users' => array('*'),
				'actions' => array('getEncrypted')
			),*/
			array('deny', // deny all users
				'users' => array('*'),
			),
		);
		
	}

	public function actionDropbox()
	{
		$oauthCache = Yii::getPathOfAlias('application') . '/runtime/oauth.cache';
		$tokens = unserialize(file_get_contents($oauthCache));

		
		$opts = array(
			'roots' => array(
				array(
					'driver'			 => 'Dropbox',
					'accessToken'		 => $tokens['token'],
					'accessTokenSecret'	 => $tokens['token_secret'],
					'path'				 => '/',
					'root'				 => 'sandbox',
					'consumerKey'		 => ELFINDER_DROPBOX_CONSUMERKEY,
					'consumerSecret'	 => ELFINDER_DROPBOX_CONSUMERSECRET,
					'tmpPath'			 => Yii::getPathOfAlias('application') . '/runtime/dropboxcache',
				)
			)
		);

		$connector = new elFinderConnector(new elFinder($opts));
		$connector->run();
	}

	public function actionFilesystem()
	{
		$opts = array(
			'roots' => array(
				array(
					'driver'			=> 'LocalFileSystem',
					'alias'				=> 'Localfiles',
					'URL'				=> $this->createAbsoluteUrl('/') . '/' . $this->_filePath,
					'tmbURL'			=> $this->createAbsoluteUrl('/') . '/' . $this->_filePath . '/.tmb',
					'path'				=>	Yii::getPathOfAlias('webroot') . '/' . $this->_filePath,
				)
			)
		);

		$connector = new elFinderConnector(new elFinder($opts));
		$connector->run();
	}
	
	public function actionFilesystemEncrypted()
	{
		$opts = array(
			'roots' => array(
				array(
					'driver'			=> 'LocalFileSystemEncrypted',
					'alias'				=> 'Encrypted Localfiles',
					'URL'				=> $this->createAbsoluteUrl('getEncrypted') . '/',
					'tmbPath'			=> false,
					'path'				=>	Yii::getPathOfAlias('webroot') . '/' . $this->_encryptedPath,
				)
			)
		);

		$connector = new elFinderConnector(new elFinder($opts));
		$connector->run();
	}
	
	public function actionGetEncrypted()
	{
		$file = Yii::app()->getRequest()->getParam('file');
		if (!$file) {
			throw new CHttpException(404, 'File not found');
		}
		$path = Yii::getPathOfAlias('webroot') . '/' . $this->_encryptedPath . '/' . Yii::app()->getRequest()->getParam('file');
		$content = Yii::app()->crypt->decrypt(file_get_contents($path));

		header('Content-Type: application/octet-stream'); 
		header('Content-Disposition: attachment; ' . basename($file));
		header('Content-Location: ' . basename($file));
		header('Content-Transfer-Encoding: binary');
		header('Content-Length: ' . strlen($content));
		header('Connection: close');
		echo $content;
		Yii::app()->end();
	}
}

?>
