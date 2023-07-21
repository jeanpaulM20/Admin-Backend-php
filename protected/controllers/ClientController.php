<?php

class ClientController extends Controller {

	public $defaultAction = 'admin';
	public $layout = '//layouts/column1';

	/**
	 * @return array action filters
	 */
	public function filters() {
		return array(
			'accessControl', // perform access control for CRUD operations
		);
	}

	/**
	 * Specifies the access control rules.
	 * This method is used by the 'accessControl' filter.
	 * @return array access control rules
	 */
	public function accessRules() {
		return array(
			array('allow',
				'users' => array('@'),
			),
			array('deny', // deny all users
				'users' => array('*'),
			),
		);
	}

	public function actionView($id) {
		$model = $this->loadModel($id);
		$this->render('view', array(
			'model' => $model,
		));
	}
	
	/**
	 * Creates a new model.
	 * If creation is successful, the browser will be redirected to the 'view' page.
	 */
	public function actionCreate() {
		$model = new Client;
		$oldData = array();

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1a791f);

		if (isset($_POST['Client'])) {
			$model->attributes = $_POST['Client'];
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
	public function actionUpdate($id) {
		$model = $this->loadModel($id);
		$oldData = $model->attributes;

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@1a791f);

		if (isset($_POST['Client'])) {
			$model->attributes = $_POST['Client'];
			if (!isset($_POST['Client']['trainers'])) {
				$model->trainers = array();
			}
			if (!isset($_POST['Client']['contents'])) {
				$model->contents = array();
			}
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
	public function actionDelete($id) {
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

	/**
	 * Manages all models.
	 */
	public function actionAdmin() {
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		if (Yii::app()->request->getParam('export')) {
			$this->actionExport();
			Yii::app()->end();
		}

		$model = new Client('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Client']))
			$model->attributes = $_GET['Client'];

		$this->render('admin', array(
			'model' => $model,
		));
	}

	/**
	 * Returns the data model based on the primary key given in the GET variable.
	 * If the data model is not found, an HTTP exception will be raised.
	 * @param integer the ID of the model to be loaded
	 */
	public function loadModel($id) {
		$model = Client::model()->findByPk($id);
		if ($model === null)
			throw new CHttpException(404, 'The requested page does not exist.');
		return $model;
	}

	public function getModel() {
		return Client::model();
	}

	/**
	 * Performs the AJAX validation.
	 * @param CModel the model to be validated
	 */
	protected function performAjaxValidation($model) {
		if (isset($_POST['ajax']) && $_POST['ajax'] === 'client-form') {
			echo CActiveForm::validate($model);
			Yii::app()->end();
		}
	}

	public function gridActionColumn($data, $row) {
		$list = array('view' => 'View', 'update' => 'Edit', 'delete' => 'Delete', 'credits' => 'Credits', 'qrcode' => 'Get QR code', 'anamnese' => 'Anamnese', 'anamnesepdf' => 'Anamnese PDF');
		return CHtml::dropDownList('actions', '', $list, array('empty' => '(Action)', 'onchange' => 'js:processAction($(this).val(), ' . $data->id . ');')
		);
	}

	public function gridActiveColumn($data, $row) {
		if ($data->active) {
			return 'x';
		} else {
			return '';
		}
	}

	public function gridQrStaticColumn($data, $row) {
		if ($data->qrcode_static) {
			return 'x';
		} else {
			return '';
		}
	}

	public function gridDoorAccessColumn($data, $row) {
		if ($data->door_access) {
			return 'x';
		} else {
			return '';
		}
	}

	public function actionExport() {
		$fp = fopen('php://temp', 'w');
		$headers = array(
			'id',
			'clientid',
			'clientpasscode',
			'surname',
			'name',
			array(
				'name' => 'birthday',
				'class' => 'application.extensions.datecolumn.SYDateColumn',
			),
			'e_mail',
			'zip',
			'domicile',
			'phone',
			'mobile',
			'foto',
			array(
				'name' => 'active',
				'value' => array($this, 'gridActiveColumn'),
				'filter' => CHtml::listData(
						array(
					array('id' => '1', 'title' => 'Active'),
					array('id' => '0', 'title' => 'Not Active'),
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

		$model = new Client('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Client'])) {
			$model->attributes = $_GET['Client'];
		}
		$provider = $model->search();

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

	public function actionExportFile() {
		Yii::app()->request->sendFile('Client.csv', Yii::app()->user->getState('export'));
		Yii::app()->user->clearState('export');
	}

	public function actionFoto($id) {
		$model = $this->loadModel($id);
		if ($model && $model->foto) {
			echo '<img src="' . $model->foto . '" />';
		} else {
			echo '';
		}
	}

	public function actionQrcode($id) {
		$client = $this->loadModel($id);
		Header("Content-type: image/png");
		$client->getQRCodeImage();
	}

	public function actionAnamnese($id) {
		$client = $this->loadModel($id);
		if (!$client->anamnese) {
			$anamnese = new ClientAnamnese;
			$anamnese->client_id = $id;
			$anamnese->save();
		} else {
			$anamnese = $client->anamnese;
		}
		if (isset($_POST['ClientAnamnese'])) {
			$anamnese->attributes = $_POST['ClientAnamnese'];
			$anamnese->save();
		}

		$this->render('anamnese', array(
			'anamnese' => $anamnese,
		));
	}
	
	public function actionAnamnesepdf($id) {
		$client = $this->loadModel($id);
		if (!$client->anamnese) {
			$anamnese = new ClientAnamnese;
			$anamnese->client_id = $id;
			$anamnese->save();
		} else {
			$anamnese = $client->anamnese;
		}
		$this->_getAnamnesePDF($anamnese);
	}

	protected function _getAnamnesePDF($anamnese)
	{
		if (!is_object($anamnese)) {
			$anamnese = ClientAnamnese::model()->findByPk($anamnese);
		}
		
		$html2pdf = Yii::app()->ePdf->HTML2PDF();
        $html2pdf->WriteHTML($this->renderPartial('anamnesepdf', array('anamnese' => $anamnese), true));
        $html2pdf->Output('Anamnese_' . $anamnese->client->getModelDisplay() .'.pdf', 'D');  
	}
	
	public function actionFeedback()
	{
		if (isset($_GET['pageSize'])) {
			Yii::app()->user->setState('pageSize', (int) $_GET['pageSize']);
			unset($_GET['pageSize']);
		}

		$model	= new Feedback('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['Feedback']))
			$model->attributes	 = $_GET['Feedback'];

		$this->render('feedback', array(
			'model' => $model,
		));
	}
}
