<?php

class LockerController extends Controller
{

	public $defaultAction = 'admin';
	public $layout = '//layouts/column1';

	/**
	 * @return array action filters
	 */
	public function filters()
	{
		return array(
			'accessControl', // perform access control for CRUD operations
		);
	}

	/**
	 * Specifies the access control rules.
	 * This method is used by the 'accessControl' filter.
	 * @return array access control rules
	 */
	public function accessRules()
	{
		return array(
			array('allow',
				'actions' => array('reportDoorStatus', 'getTrainings', 'checkClient', 'getAppointment', 'getServerCert', 'putClientKey', 'getCommands', 'reportCommandCompletion'),
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

	/**
	 * Creates a new model.
	 * If creation is successful, the browser will be redirected to the 'view' page.
	 */
	public function actionCreate()
	{
		$model	 = new Locker;
		$oldData = array();

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1071e12);

		if (isset($_POST['Locker'])) {
			$model->attributes = $_POST['Locker'];
			if ($model->save()) {
				$this->redirect(array('admin'));
			}
		}

		$this->render('create', array(
			'model' => $model,
		));
	}

	/**
	 * Updates a particular model.
	 * If update is successful, the browser will be redirected to the 'view' page.
	 * @param integer $id the ID of the model to be updated
	 */
	public function actionUpdate($id)
	{
		$model	 = $this->loadModel($id);
		$oldData = $model->attributes;

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1071e12);

		if (isset($_POST['Locker'])) {
			$model->attributes = $_POST['Locker'];
			if ($model->save()) {
				$this->redirect(array('admin'));
			}
		}

		$this->render('update', array(
			'model' => $model,
		));
	}

	/**
	 * Deletes a particular model.
	 * If deletion is successful, the browser will be redirected to the 'admin' page.
	 * @param integer $id the ID of the model to be deleted
	 */
	public function actionDelete($id)
	{
		if (Yii::app()->request->isPostRequest) {
			// we only allow deletion via POST request
			$this->loadModel($id)->delete();

			// if AJAX request (triggered by deletion via admin grid view), we should not redirect the browser
			if (!isset($_GET['ajax']))
				$this->redirect(isset($_POST['returnUrl']) ? $_POST['returnUrl'] : array('admin'));
		}
		else
			throw new CHttpException(400, 'Invalid request. Please do not repeat this request again.');
	}
	
	public function actionOpenMan() {
		$lockers = Locker::model()->men()->findAll();
		foreach ($lockers as $locker) {
			$locker->admin_open = 1;
			$locker->save();
		}
		$this->redirect(array('admin'));
	}
	
	public function actionOpenWoman() {
		$lockers = Locker::model()->women()->findAll();
		foreach ($lockers as $locker) {
			$locker->admin_open = 1;
			$locker->save();
		}
		$this->redirect(array('admin'));
	}
	
	public function actionApprove($id)
	{
		if (Yii::app()->request->isPostRequest) {
			// we only allow deletion via POST request
			$this->loadModel($id)->approveKey();

			// if AJAX request (triggered by deletion via admin grid view), we should not redirect the browser
			if (!isset($_GET['ajax']))
				$this->redirect(isset($_POST['returnUrl']) ? $_POST['returnUrl'] : array('admin'));
		}
		else
			throw new CHttpException(400, 'Invalid request. Please do not repeat this request again.');
	}
	
	public function actiondecline($id)
	{
		if (Yii::app()->request->isPostRequest) {
			// we only allow deletion via POST request
			$this->loadModel($id)->declineKey();

			// if AJAX request (triggered by deletion via admin grid view), we should not redirect the browser
			if (!isset($_GET['ajax']))
				$this->redirect(isset($_POST['returnUrl']) ? $_POST['returnUrl'] : array('admin'));
		}
		else
			throw new CHttpException(400, 'Invalid request. Please do not repeat this request again.');
	}

	/**
	 * Manages all models.
	 */
	public function actionAdmin()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		if (Yii::app()->request->getParam('export')) {
			$this->actionExport();
			Yii::app()->end();
		}

		$model				 = new Locker('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Locker']))
			$model->attributes	 = $_GET['Locker'];

		$this->render('admin', array(
			'model' => $model,
		));
	}

	public function actionLog()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		if (Yii::app()->request->getParam('export')) {
			$this->actionExport();
			Yii::app()->end();
		}

		$model				 = new LockerLog('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['LockerLog']))
			$model->attributes	 = $_GET['LockerLog'];

		$this->render('log', array(
			'model' => $model,
		));
	}

	/**
	 * Returns the data model based on the primary key given in the GET variable.
	 * If the data model is not found, an HTTP exception will be raised.
	 * @param integer the ID of the model to be loaded
	 */
	public function loadModel($id)
	{
		$model = Locker::model()->findByPk($id);
		if ($model === null)
			throw new CHttpException(404, 'The requested page does not exist.');
		return $model;
	}

	public function getModel()
	{
		return Locker::model();
	}

	/**
	 * Performs the AJAX validation.
	 * @param CModel the model to be validated
	 */
	protected function performAjaxValidation($model)
	{
		if (isset($_POST['ajax']) && $_POST['ajax'] === 'locker-form') {
			echo CActiveForm::validate($model);
			Yii::app()->end();
		}
	}

	public function gridActionColumn($data, $row)
	{
		$list = array('update' => 'Edit', 'delete' => 'Delete');
		if ($data->key_request) {
			$list['approve'] = 'Approve key';
			$list['decline'] = 'Decline key';
		}
		return CHtml::dropDownList('actions', '', $list, array('empty'		 => '(Action)', 'onchange'	 => 'js:processAction($(this).val(), ' . $data->id . ');')
		);
	}

	public function gridActiveColumn($data, $row)
	{
		if ($data->active) {
			return 'x';
		} else {
			return '';
		}
	}

	public function gridPublishedColumn($data, $row)
	{
		if ($data->published) {
			return 'x';
		} else {
			return '';
		}
	}

	public function actionExport()
	{
		$fp		 = fopen('php://temp', 'w');
		$headers = array(
			'id',
			'name',
			'address',
			'zip',
			'city',
			'opening_times',
			'e_mail',
			'phone',
			'foto',
			'longitude',
			'latitude',
			array(
				'name'	 => 'active',
				'value'	 => array($this, 'gridActiveColumn'),
				'filter' => CHtml::listData(
						array(
					array('id'	 => '1', 'title'	 => 'Active'),
					array('id'	 => '0', 'title'	 => 'Not Active'),
						), 'id', 'title'),
			),
			array(
				'name'	 => 'published',
				'value'	 => array($this, 'gridPublishedColumn'),
				'filter' => CHtml::listData(
						array(
					array('id'	 => '1', 'title'	 => 'Published'),
					array('id'	 => '0', 'title'	 => 'Not Published'),
						), 'id', 'title'),
			),
		);

		$row = array();
		foreach ($headers as $header) {
			if (is_array($header)) {
				$row[] = $this->getModel()->getAttributeLabel($header['name']);
			} else {
				$row[] = $this->getModel()->getAttributeLabel($header);
			}
		}
		fputcsv($fp, $row);

		$model = new Location('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Location'])) {
			$model->attributes	 = $_GET['Location'];
		}
		$provider			 = $model->search();

		foreach ($provider->getData() as $model) {
			$row = array();
			foreach ($headers as $header) {
				if (is_array($header)) {
					if (isset($header['value'])) {
						$row[] = $this->evaluateExpression($header['value'], array('data' => $model));
					} else {
						$row[] = CHtml::value($model, $header['name']);
					}
				} else {
					$row[] = CHtml::value($model, $header);
				}
			}
			fputcsv($fp, $row);
		}
		rewind($fp);
		Yii::app()->user->setState('export', stream_get_contents($fp));
		fclose($fp);
	}

	public function actionExportFile()
	{
		Yii::app()->request->sendFile('Location.csv', Yii::app()->user->getState('export'));
		Yii::app()->user->clearState('export');
	}

	public function actionReportDoorStatus()
	{
		$locker_id		 = Yii::app()->getRequest()->getParam('LockerID', false);
		$result			 = new stdClass();
		$result->status	 = 'failed';
		if (!$locker_id) {
			$result->error = 'Missing required params';
			echo CJSON::encode($result);
			Yii::app()->end();
		} else {
			$locker = Locker::model()->find('locker_id = :locker_id', array('locker_id' => $locker_id));
			if (!$locker) {
				$result->error = 'Wrong locker id';
				echo CJSON::encode($result);
				Yii::app()->end();
			} else {
				$data = $this->_getRequestData($locker);
				if ($data && isset($data['status'])) {
					$locker->status = $data['status'];
					if ($locker->status == 'free') {
						LockerLog::logAction('Logout', $locker_id, $locker->client_id);
						$locker->client_id	 = null;
						$locker->training_id = null;
						$stats = @$data['stats'];
						if ($stats) {
							$stats = CJSON::decode(urldecode($stats));
							foreach ($stats as $screen => $statdata) {
								$stat = new Screenstats();
								$stat->locker_id = $locker->id;
								$stat->screen = $screen;
								$stat->time = $statdata['time'];
								$stat->visits = $statdata['visits'];
								$stat->clicks = $statdata['clicks'];
								$stat->subclicks = $statdata['subclicks'];
								$stat->save();
							}
						}
					} else {
						LockerLog::logAction('Locker ' . $data['status'], $locker_id, $locker->client_id);
					}
					$result->status		 = 'ok';
					$locker->request_num++;
					$locker->save();
					$this->_sendResponse($result, $locker);
				} else {
					$result->error = 'Wrong request data';
					echo CJSON::encode($result);
					Yii::app()->end();
				}
			}
		}
	}

	public function actionGetTrainings()
	{
		$locker_id		 = Yii::app()->getRequest()->getParam('LockerID', false);
		$locker = Locker::model()->find('locker_id = :locker_id', array('locker_id' => $locker_id));
		$result			 = new stdClass;
		$result->status	 = 'failed';
		if ($locker) {
			$data = $this->_getRequestData($locker);
			if ($data && isset($data['ClientID']) && $data['ClientID']) {
				$result->status	 = 'ok';
				$reviews		 = Yii::app()->db->createCommand()
						->select('r.id, r.type, t.date, t.starttime')
						->from('tbl_review r')
						->join('tbl_training t', 'r.training_id=t.id')
						->where('t.client_id = :client', array('client'	=> $data['ClientID']));
				$result->trainings	 = array();
				foreach ($reviews->queryAll() as $one) {
					$result->trainings[$one['id']] = array(
						$one['date'] . ' ' . $one['starttime'],
						$one['type'] . ''
					);
				}
				$this->_sendResponse($result, $locker);
				$locker->request_num++;
				$locker->save();
			} else {
				$result->error = 'Wrong request data';
				echo CJSON::encode($result);
				Yii::app()->end();
			}
		} else {
			$result->error = 'Wrong request data';
			echo CJSON::encode($result);
			Yii::app()->end();
		}
	}

	public function actionCheckClient()
	{
		$locker_id		 = Yii::app()->getRequest()->getParam('LockerID', false);
		$locker = Locker::model()->find('locker_id = :locker_id', array('locker_id' => $locker_id));
		$result			 = new stdClass;
		$result->status	 = 'failed';
		$result->error = 'Wrong request data';
		if ($locker) {
			$data = $this->_getRequestData($locker);
			if ($data) {
				$password = @$data['password'];
				$rootPass = Yii::app()->cfg->getItem('locker_master_password');
				if ($rootPass == $password) {
					unset($result->error);
					$result->status			 = 'ok';
					$result->clientFullName	 = 'root';
					$result->ClientID		 = 'root';
				} elseif ($locker->client && $locker->client->clientpasscode == $password) {
					unset($result->error);
					$result->status			 = 'ok';
					$result->clientFullName	 = $locker->client->getFullname();
					$result->ClientID		 = $locker->client->id;
					$result->gender			 = $locker->client->gender;
					$result->maxHeartRate = $locker->client->max_heart_rate;
					$result->minHeartRate = $locker->client->min_heart_rate;
					$result->token = Clientaccesstoken::generate($locker->client)->token;
					LockerLog::logAction('Login', $locker_id, $locker->client->id);
				} elseif (Yii::app()->cfg->getItem('locker_staff_password') == $password) {
					unset($result->error);
					$result->status			 = 'ok';
					$result->clientFullName	 = 'staff';
					$result->ClientID		 = 'staff';
				} else if (!$locker->client && isset($data['client_email'])) {
					$client = Client::model()->find('e_mail = :email', array('email' => $data['client_email']));
					if ($client && $client->clientpasscode == $password) {
						$reserwed = Locker::model()->findAllByAttributes(array('client_id' => $client->id));
						foreach ($reserwed as $one) {
							$one->client_id	 = null;
							$one->training_id = null;
							$one->save();
						}
						
						$training = Training::getNextTrainingByClient($client->id);
						if ($training) {
							$locker->training_id = $training->id;
						}
						$locker->client_id = $client->id;
						$locker->save();
						unset($result->error);
						$result->status			 = 'ok';
						$result->clientFullName	 = $client->getFullname();
						$result->ClientID		 = $client->id;
						$result->gender			 = $client->gender;
						$result->maxHeartRate = $client->max_heart_rate;
						$result->minHeartRate = $client->min_heart_rate;
						$result->token = Clientaccesstoken::generate($client)->token;
						LockerLog::logAction('Login', $locker_id, $client->id);
					}
				}
				$locker->request_num++;
				$locker->save();
			}
			$this->_sendResponse($result, $locker);
		} else {
			echo CJSON::encode($result);
			Yii::app()->end();
		}
	}

	public function actionGetCommands() {
		$locker_id		 = Yii::app()->getRequest()->getParam('LockerID', false);
		$locker = Locker::model()->find('locker_id = :locker_id', array('locker_id' => $locker_id));
		if ($locker) {
			$locker->request_num++;
			$locker->save();
			if ($locker->admin_open) {
				return $this->_sendResponse(array(
					 array("cmd"=>"open-door", "id"=>"1")
				), $locker);
			} else {
				return $this->_sendResponse(array(), $locker);
			}
		} else {
			$result			 = new stdClass;
			$result->status	 = 'failed';
			$result->error = 'Wrong request data';
			echo CJSON::encode($result);
			Yii::app()->end();
		}
	}
	
	public function actionReportCommandCompletion() {
		$locker_id		 = Yii::app()->getRequest()->getParam('LockerID', false);
		$locker = Locker::model()->find('locker_id = :locker_id', array('locker_id' => $locker_id));
		if ($locker) {
			$data = $this->_getRequestData($locker);
			if ($data['commands']) {
				foreach ($data['commands'] as $command) {
					if ($command['cmd'] == 'open-door' && $command['status'] == 'done') {
						$locker->admin_open = 0;
					}
				}
			}
			$locker->request_num++;
			$locker->save();
			$result			 = new stdClass;
			$result->status = 'ok';
			$this->_sendResponse($result, $locker);
		} else {
			$result			 = new stdClass;
			$result->status	 = 'failed';
			$result->error = 'Wrong request data';
			echo CJSON::encode($result);
			Yii::app()->end();
		}
	}


	public function actionGetAppointment()
	{
		$locker_id		 = Yii::app()->getRequest()->getParam('LockerID', false);
		$locker = Locker::model()->find('locker_id = :locker_id', array('locker_id' => $locker_id));
		$result			 = new stdClass;
		$result->status	 = 'failed';
		$result->error = 'Wrong request data';
		if ($locker) {
			$data = $this->_getRequestData($locker);
			if ($data) {
				$result->status		 = 'ok';
				unset($result->error);
				$result->appointment = new stdClass();
				if ($locker->client) {
					$result->appointment->ClientID				 = $locker->client->id;
					$result->appointment->ClientFullName		 = $locker->client->getFullname();
					$result->appointment->ClientToken			 = $locker->client->getTokenForLocker()->token;
					$result->appointment->password				 = $locker->client->clientpasscode;
					$result->appointment->gender				 = $locker->client->gender;
					$result->appointment->lang					= $locker->client->preference ? $locker->client->preference->preferred_language->language : 'de';
				}
				if ($locker->training) {
					$result->appointment->appointmentStartDate	 = $locker->training->date . ' ' . $locker->training->starttime;
					$result->appointment->appointmentStopDate	 = $locker->training->date . ' ' . $locker->training->getEndTime();
					$result->appointment->maxHeartRate = $locker->training->client->max_heart_rate;
					$result->appointment->minHeartRate = $locker->training->client->min_heart_rate;
					if (!$result->appointment->ClientToken) {
						$result->appointment->ClientToken = $locker->training->client->getTokenForLocker()->token;
					}
				}
				$locker->request_num++;
				$locker->save();
			}
			$this->_sendResponse($result, $locker);
		} else {
			echo CJSON::encode($result);
			Yii::app()->end();
		}
	}

	protected function _getPublicKey()
	{
		return file_get_contents(Yii::getPathOfAlias('application') . '/server.cer');
	}
	
	protected function _getPrivateKey()
	{
		return file_get_contents(Yii::getPathOfAlias('application') . '/server.key');
	}
	
	public function actionGetServerCert()
	{
		echo $this->_getPublicKey();
		Yii::app()->end();
	}
	
	public function actionPutClientKey()
	{
		$result = new stdClass();
		
		$locker_id		 = Yii::app()->getRequest()->getParam('LockerID', false);
		$locker = false;
		if (!$locker_id) {
			echo 'Locker ID not provided';
		} else {
			$locker = Locker::model()->find('locker_id = :locker_id', array('locker_id' => $locker_id));
			if (!$locker) {
				echo 'Wrong Locker ID';
			} else {
				$encrypted = file_get_contents($_FILES["key"]["tmp_name"]);
				$key = openssl_pkey_get_private($this->_getPrivateKey());
				if($key===FALSE){
					echo  "failed to open key";
				}
				$decrypted ="";
				$status = openssl_private_decrypt($encrypted, $decrypted, $key, OPENSSL_NO_PADDING);
				if($status){
					$locker->key_request = $decrypted;
					if(!$locker->save()){
						echo  "failed to save";
					} else {
						echo "OK";
						if ($locker->locker_id == 'AppleDemoID') {
							$locker->approveKey();
						}
					}
				} else {
					echo "failed to decrypt";
				}
			}
		}
		Yii::app()->end();
	}
	
	protected function _sendResponse($data, $locker)
	{
		if ($locker && $locker->key) {
			$algo = MCRYPT_RIJNDAEL_128;
			$mode = MCRYPT_MODE_CBC;
			$module = mcrypt_module_open($algo, "", $mode, "");
			$keySize = 16;
			$blockSize = mcrypt_enc_get_block_size($module);
			mcrypt_module_close($module);
			$iv= substr($locker->key,$keySize,$blockSize);
			$key = substr($locker->key, 0, $keySize);
			$plainText = CJSON::encode($data);
			$padding = 16 - strlen($plainText)%16;
			for($i=$padding;$i>0;$i--){
				$plainText.=chr($padding);
			}
			echo mcrypt_encrypt($algo,$key, $plainText, $mode, $iv);
		} else {
			$res = new stdClass();
			$res->status = "failed";
			$res->error = "Encryption problem";
			echo CJSON::encode($res);
		}
		Yii::app()->end();
	}
	
	protected function _getRequestData($locker) {
		$data = false;
		if ($locker && $locker->key && $encrypted = Yii::app()->getRequest()->getParam('data', false)) {
			$algo = MCRYPT_RIJNDAEL_128;
			$mode = MCRYPT_MODE_CBC;
			$module = mcrypt_module_open($algo, "", $mode, "");
			$keySize = 16;
			$blockSize = mcrypt_enc_get_block_size($module);
			mcrypt_module_close($module);
			$iv= substr($locker->key,$keySize,$blockSize);
			$key = substr($locker->key, 0, $keySize);

			$decrypted=mcrypt_decrypt($algo,$key, base64_decode($encrypted), $mode, $iv);
			$padding = ord($decrypted[strlen($decrypted)-1]);
			if($padding>0 && $padding<17){
				$decrypted = substr($decrypted, 0, -$padding);
			}
			$data = CJSON::decode($decrypted);
		}
		if ($data && isset($data['reqN']) && $data['reqN'] <= $locker->request_num) {
			$data = false;
		}
		return $data;
	}
}