<?php
defined('ELFINDER_DROPBOX_CONSUMERKEY') or define('ELFINDER_DROPBOX_CONSUMERKEY',    'hpurnn9ni1kqi1g');
defined('ELFINDER_DROPBOX_CONSUMERSECRET') or define('ELFINDER_DROPBOX_CONSUMERSECRET', 'nvz3ms2luqphcz3');
spl_autoload_unregister(array('YiiBase','autoload'));
Yii::import('application.vendors.Elfinder.Dropbox.autoload', true);
spl_autoload_register(array('YiiBase','autoload'));
		
Yii::import('application.vendors.*');
require_once 'Zend/Oauth/Consumer.php';

class DropboxController extends Controller
{
	
	public function actionSetup() {
		$oauthCache = Yii::app()->basePath . '/runtime/oauth.cache';
		
		$oauth = new Dropbox_OAuth_Zend(ELFINDER_DROPBOX_CONSUMERKEY, ELFINDER_DROPBOX_CONSUMERSECRET);
		$tokens = $oauth->getRequestToken();
		file_put_contents($oauthCache, serialize($tokens));
		$this->redirect($oauth->getAuthorizeUrl($this->createAbsoluteUrl('dropbox/finish')), true);
	}
	
	public function actionFinish() {
		$oauthCache = Yii::app()->basePath . '/runtime/oauth.cache';
		$tokens = unserialize(file_get_contents($oauthCache));
		$oauth = new Dropbox_OAuth_Zend(ELFINDER_DROPBOX_CONSUMERKEY, ELFINDER_DROPBOX_CONSUMERSECRET);
		$oauth->setToken($tokens);
		$tokens = $oauth->getAccessToken();
		$oauth->setToken($tokens);
		$dropbox = new Dropbox_API($oauth);
		$result = $dropbox->getAccountInfo();
		if (isset($result['uid'])) {
			file_put_contents($oauthCache, serialize($tokens));
			$this->redirect($this->createUrl("/"));
		}
		else {
			die("An error occurred, unable to confirm connection with dropbox api\n");
		}

	}
}
