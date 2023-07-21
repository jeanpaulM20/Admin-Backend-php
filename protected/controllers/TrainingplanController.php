<?php

class TrainingplanController extends Controller
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
		if (isset($_POST['TrainingPlan']) && isset($_POST['TrainingPlan']['id']) && $_POST['TrainingPlan']['id']) {
			$model = $this->loadModel($_POST['TrainingPlan']['id']);
		} else {
			unset($_POST['TrainingPlan']['id']);
			$model	 = new TrainingPlan;
		}
		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@20dcb7);

		if (isset($_POST['TrainingPlan'])) {
			
			$model->attributes = $_POST['TrainingPlan'];
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

		// Uncomment the following line if AJAX validation is needed
		// $this->performAjaxValidation(ch.esgroup.domainconverter.DomainModel@20dcb7);

		if (isset($_POST['TrainingPlan'])) {
			$model->attributes = $_POST['TrainingPlan'];
			if ($model->save()) {
				$this->redirect(array('admin'));
			}
		}

		$this->render('update', array(
			'model' => $model,
		));
	}
	
	public function actionByClient($id)
	{
		echo CJSON::encode(TrainingPlan::getDropdownListByClientId($id));
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

		$model				 = new TrainingPlan('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['TrainingPlan']))
			$model->attributes	 = $_GET['TrainingPlan'];

		$this->render('admin', array(
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
		$model = TrainingPlan::model()->findByPk($id);
		if ($model === null)
			throw new CHttpException(404, 'The requested page does not exist.');
		return $model;
	}

	public function getModel()
	{
		return TrainingPlan::model();
	}

	/**
	 * Performs the AJAX validation.
	 * @param CModel the model to be validated
	 */
	protected function performAjaxValidation($model)
	{
		if (isset($_POST['ajax']) && $_POST['ajax'] === 'trainingplan-form') {
			echo CActiveForm::validate($model);
			Yii::app()->end();
		}
	}

	public function gridActionColumn($data, $row)
	{
		$list = array('update' => 'Edit', 'delete' => 'Delete', 'pdf' => 'Download as PDF');
		return CHtml::dropDownList('actions', '', $list, array('empty'		 => '(Action)', 'onchange'	 => 'js:processAction($(this).val(), ' . $data->id . ');')
		);
	}

	public function actionExport()
	{
		$fp		 = fopen('php://temp', 'w');
		$headers = array(
			'id',
			array(
				'name' => 'client_search',
				'value'=>'$data->client->clientid  . " " . $data->client->surname  . " " . $data->client->name ',
			),
			'new_pro',
			'load_duration', 
			'repeat',
			'temp',
			'rates',
			'phase',
			'personal_week',
			'own_week',
			'goal',
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

		$model = new TrainingPlan('search');
		$model->unsetAttributes();  // clear any default values
		if (isset($_GET['TrainingPlan'])) {
			$model->attributes	 = $_GET['TrainingPlan'];
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
		Yii::app()->request->sendFile('TrainingPlan.csv', Yii::app()->user->getState('export'));
		Yii::app()->user->clearState('export');
	}

	public function actionAutosave()
	{
		$data = $_POST['TrainingPlan'];
		if (isset($data['id']) && $data['id']) {
			$trainingPlan = $this->loadModel($data['id']);
		} else {
			unset($data['id']);
			$trainingPlan = new TrainingPlan;
		}
		$trainingPlan->attributes = $data;
		$trainingPlan->save();
		echo CJSON::encode($trainingPlan->attributes);
	}
	
	public function actionPdf($id)
	{
		$model	 = $this->loadModel($id);

		$this->_getPDF($model);
	}
	
	protected function _getPDF($trainingPlan)
	{
		if (!is_object($trainingPlan)) {
			$trainingPlan = TrainingPlan::model()->findByPk($trainingPlan);
		}
		
		$tmpfile = false;
		if(!ini_get('allow_url_fopen') && $trainingPlan->client && $trainingPlan->client->foto) {
				$ch = curl_init();
				curl_setopt ($ch, CURLOPT_URL, $trainingPlan->client->foto);
				curl_setopt ($ch, CURLOPT_RETURNTRANSFER, 1);
				curl_setopt ($ch, CURLOPT_CONNECTTIMEOUT, 10);
				$tmpfile = tempnam(Yii::getPathOfAlias('application.runtime'), 'tmp');
				file_put_contents($tmpfile, curl_exec($ch));
				curl_close($ch);
				$trainingPlan->client->foto = $tmpfile;
			}
		
		$html2pdf = Yii::app()->ePdf->HTML2PDF();
        $html2pdf->WriteHTML($this->renderPartial('pdf', array('model' => $trainingPlan), true));
        $html2pdf->Output('trainingplan_' . $trainingPlan->getModelDisplay() .'.pdf', 'D');  
		
		if($tmpfile) {
			@unlink($tmpfile);
		}
	}
}
