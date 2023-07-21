<?php

class ApiAccessFilter extends CFilter
{
	public $restricted_urls = array();
	
	public static $salt = 'sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op';
	
	protected function preFilter($filterChain)
    {
		$path = Yii::app()->getRequest()->getPathInfo();
        foreach ($this->restricted_urls as $rule) {
			if (preg_match('|^' . $rule . '|', $path) == 1) {
				if (isset($_SERVER['HTTP_X_AUTH_TOKEN'])) {
					$trainers = Trainer::model()->findAll();
					foreach ($trainers as $trainer) {
						if ($_SERVER['HTTP_X_AUTH_TOKEN'] == md5(ApiAccessFilter::$salt . $trainer->passcode)) {
							@$filterChain->controller->current_trainer = $trainer;
							return true;
						}
					}
					
					$token = Clientaccesstoken::model()->with(array(
						'client' => array(
							'condition' => 'active=1', 
							'together'=>true
						)
					))->findByAttributes(array('token' => $_SERVER['HTTP_X_AUTH_TOKEN']));
					if ($token) {
						@$filterChain->controller->current_client = $token->client;
						return true;
					}
				} 
				throw new CHttpException(403,Yii::t('yii','You are not authorized to perform this action.'));
			}
		}
        return true; 
    }
}
?>
