<?php
class DoorController extends Controller
{
	/**
	 * Default response format
	 * either 'json' or 'xml'
	 */
	private $format = 'json';
	public $defaultAction = 'admin';

	public function filters()
	{
		return array(
			'accessControl', // perform access control for CRUD operations
		);
	}

	public function accessRules()
	{
		return array(
			array('allow',
				'actions' => array('reportDoorStatus', 'getPlannedVisitors', 'checkAccessCode'),
				'users' => array('*'),
			),
			array('allow',
				'users' => array('@'),
			),
			array('deny', // deny all users
				'users' => array('*'),
			),
		);
	}

	public function actionAdmin()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		$model				 = new DoorLog('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['DoorLog']))
			$model->attributes	 = $_GET['DoorLog'];

		$this->render('admin', array(
			'model' => $model,
		));
	}

	public function actionCheckAccessCode()
	{
		$code = Yii::app()->getRequest()->getParam('code', '');
		$result = array();
		if ($code) {
			$client = Client::model()
				->active()
				->findByAttributes(array('qrcode' => $code));
			if ($client) {
				if (!$client->door_access) {
					DoorLog::logActionClient($client->id, DoorLog::NO_ACCESS, 'Client door access is restricted');
					$result['status'] = 'reject';
				} else {
					if ($client->qrcode_static
							|| (!$client->qrcode_static && strtotime($client->qrcode_valid_to) > time())) {
						$result['status'] = 'accept';
					} else {
						DoorLog::logActionClient($client->id, DoorLog::NO_ACCESS, 'QR code no longer valid');
						$result['status'] = 'reject';
					}
				}
			} else {
				$trainer = Trainer::model()
					->active()
					->findByAttributes(array('qrcode' => $code));
				if ($trainer) {
					if (strtotime($trainer->qrcode_valid_to) > time()) {
						$result['status'] = 'accept';
					} else {
						DoorLog::logActionTrainer($trainer->id, DoorLog::NO_ACCESS, 'QR code no longer valid');
						$result['status'] = 'reject';
					}
				} else {
					DoorLog::logRefusal('Unknown QR code');
					$result['status'] = 'reject';
				}
			}
		} else {
			$result['status'] = 'error';
			$result['message'] = 'No code';
		}
		$this->_sendResponse(200, $result);
	}

	public function actionReportDoorStatus()
	{
		$code = Yii::app()->getRequest()->getParam('code', '');
		$status = Yii::app()->getRequest()->getParam('status', '');
		if ($status == 'open') {
			$trainer = Trainer::model()->active()->findByAttributes(array('qrcode' => $code));
			if ($trainer) {
				DoorLog::logActionTrainer($trainer->id);
			}
			$client = Client::model()->active()->findByAttributes(array('qrcode' => $code));
			if ($client) {
				DoorLog::logActionClient($client->id);
			}
		}
		$this->_sendResponse(200, array('status' => 'ok'));
	}

	public function actionGetPlannedVisitors()
	{
		$list = array();
		foreach (Client::model()->findAll() as $client) {
			if ($client->qrcode) {
				$list[] = $client->qrcode;
			}
		}

		foreach (Trainer::model()->findAll() as $trainer) {
			if ($trainer->qrcode) {
				$list[] = $trainer->qrcode;
			}
		}
		$this->_sendResponse(200, $list);
	}

	private function _sendResponse($status = 200, $body = '', $content_type = 'text/html', $wrapBody = true)
	{
		$status_header = 'HTTP/1.1 ' . $status . ' ' . $this->_getStatusCodeMessage($status);
		header($status_header);
		header('Content-type: ' . $content_type);

		if ($body != '') {
			if (is_string($body) && $wrapBody) {
				$body = array('status' => 'failed', 'message' => $body);
			}
			ob_start("ob_gzhandler");
			if ($wrapBody) {
				echo CJSON::encode($body);
			} else {
				echo $body;
			}
			ob_end_flush();
			Yii::app()->end();
		} else {
			$this->layout = '//layouts/column1';
			$message = '';

			switch ($status) {
				case 401:
					$message = 'You must be authorized to view this page.';
					break;
				case 404:
					$message = 'The requested URL ' . $_SERVER['REQUEST_URI'] . ' was not found.';
					break;
				case 500:
					$message = 'The server encountered an error processing your request.';
					break;
				case 501:
					$message = 'The requested method is not implemented.';
					break;
			}

			// servers don't always have a signature turned on
			// (this is an apache directive "ServerSignature On")
			$signature = ($_SERVER['SERVER_SIGNATURE'] == '') ? $_SERVER['SERVER_SOFTWARE'] . ' Server at ' . $_SERVER['SERVER_NAME'] . ' Port ' . $_SERVER['SERVER_PORT'] : $_SERVER['SERVER_SIGNATURE'];

			$this->render('body', array(
				'status' => $this->_getStatusCodeMessage($status),
				'message' => $message,
				'signature' => $signature
			));
		}
	}

	private function _getStatusCodeMessage($status)
	{
		$codes = Array(
			200 => 'OK',
			400 => 'Bad Request',
			401 => 'Unauthorized',
			402 => 'Payment Required',
			403 => 'Forbidden',
			404 => 'Not Found',
			500 => 'Internal Server Error',
			501 => 'Not Implemented',
		);
		return (isset($codes[$status])) ? $codes[$status] : '';
	}

	protected function _getHeaders() {
		if (function_exists('getallheaders')) {
			return getallheaders();
		} else {
			$headers = array();
			foreach($_SERVER as $h=>$v) {
				if(ereg('HTTP_(.+)',$h,$hp))
				$headers[$hp[1]]=$v;
			}
			return $headers;
		}
	}

	protected function _getRequestParams()
	{
		if (count($_POST) > 0) {
			return $_POST;
		}
		$str = file_get_contents('php://input');
		$json = CJSON::decode($str);
		if (is_array($json)) {
			return $json;
		}
		$result=array();
		if(function_exists('mb_parse_str')) {
			mb_parse_str($str, $result);
		} else {
			parse_str($str, $result);
		}
		return $result;
	}
}
