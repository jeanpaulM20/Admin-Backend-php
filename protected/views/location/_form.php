<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'location-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('location/create') : $this->createUrl('location/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'name'); ?>
	<?php echo $form->textField($model,'name',array('size'=>60)); ?>
	<?php echo $form->error($model,'name'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'address'); ?>
	<?php echo $form->textField($model,'address',array('size'=>60)); ?>
	<?php echo $form->error($model,'address'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'zip'); ?>
	<?php echo $form->textField($model,'zip',array('size'=>60)); ?>
	<?php echo $form->error($model,'zip'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'city'); ?>
	<?php echo $form->textField($model,'city',array('size'=>60)); ?>
	<?php echo $form->error($model,'city'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'opening_times'); ?>
	<?php $this->widget('application.extensions.elrtef.elRTE', array(
		'model' => $model,		'attribute' => 'opening_times',
		'options' => array(
			'cssClass' => 'el-rte',
			'absoluteURLs'=>true,
			'allowSource' => true,
			'styleWithCss'=>'',
			'height' => 400,
			'fmAllow'=>true,
			'fmOpen'=>'js:function(callback) {$("<div id=\"elfinder\" />").elfinder(%elfopts%);}',
			'toolbar' => 'maxi',
		),
		'elfoptions' => array(
			'url'=>'auto',
			'passkey'=>'t1fq4mstun8oq6hh606hn28fld',
			'dialog'=>array('width'=>'900','modal'=>true,'title'=>'Media Manager'),			'closeOnEditorCallback'=>true,
			'editorCallback'=>'js:callback'
		),
	));?>
	<?php echo $form->error($model,'opening_times'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'e_mail'); ?>
	<?php echo $form->textField($model,'e_mail',array('size'=>60)); ?>
	<?php echo $form->error($model,'e_mail'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'phone'); ?>
	<?php echo $form->textField($model,'phone',array('size'=>60)); ?>
	<?php echo $form->error($model,'phone'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'foto'); ?>
<?php $this->widget('application.extensions.elfinder.FilePicker',array(
	'model'=>$model,
	'attribute'=>'foto',
)); ?>	<?php echo $form->error($model,'foto'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'longitude'); ?>
	<?php echo $form->textField($model,'longitude',array('size'=>60)); ?>
	<?php echo $form->error($model,'longitude'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'latitude'); ?>
	<?php echo $form->textField($model,'latitude',array('size'=>60)); ?>
	<?php echo $form->error($model,'latitude'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'active'); ?>
	<?php echo $form->checkBox($model,'active'); ?>
	<?php echo $form->error($model,'active'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'published'); ?>
	<?php echo $form->checkBox($model,'published'); ?>
	<?php echo $form->error($model,'published'); ?></div>
		
	<div class="row">
<?php echo $form->labelEx($model,'trainers'); ?>
<?php echo CHtml::activeDropDownList($model, 'trainers', Trainer::getDropdownList(), array('multiple' => true, 'class' => 'chzn-select', 'style' => 'width:380px;')) ?>
<?php echo $form->error($model,'trainers'); ?>
</div><div class="row">
<?php echo $form->labelEx($model,'offers'); ?>
<?php echo CHtml::activeDropDownList($model, 'offers', Offer::getDropdownList(), array('multiple' => true, 'class' => 'chzn-select', 'style' => 'width:380px;')) ?>
<?php echo $form->error($model,'offers'); ?>
</div>

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('location/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
	<?php $this->widget( 'ext.EChosen.EChosen' ); ?>
</div><!-- form -->