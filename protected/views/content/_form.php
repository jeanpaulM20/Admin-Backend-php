<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'content-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('content/create') : $this->createUrl('content/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'name'); ?>
	<?php echo $form->textField($model,'name',array('size'=>60)); ?>
	<?php echo $form->error($model,'name'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'group'); ?>
	<?php echo $form->textField($model,'group',array('size'=>60)); ?>
	<?php echo $form->error($model,'group'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'type'); ?>
	<?php echo $form->dropDownList($model,'type', $model->getTypeValues()); ?>
	<?php echo $form->error($model,'type'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'preview'); ?>
<?php $this->widget('application.extensions.elfinder.FilePicker',array(
	'model'=>$model,
	'attribute'=>'preview',
)); ?>	<?php echo $form->error($model,'preview'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'teaser'); ?>
	<?php $this->widget('application.extensions.elrtef.elRTE', array(
		'model' => $model,		'attribute' => 'teaser',
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
	<?php echo $form->error($model,'teaser'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'file'); ?>
<?php $this->widget('application.extensions.elfinder.FilePicker',array(
	'model'=>$model,
	'attribute'=>'file',
)); ?>	<?php echo $form->error($model,'file'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'startdate'); ?>
	<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
		'attribute'=>'startdate',
		'model' => $model,
		'options'=>array(
			'showAnim'=>'fold',
			'dateFormat' => 'yy-mm-dd'		),
	)); ?>
	<?php echo $form->error($model,'startdate'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'enddate'); ?>
	<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
		'attribute'=>'enddate',
		'model' => $model,
		'options'=>array(
			'showAnim'=>'fold',
			'dateFormat' => 'yy-mm-dd'		),
	)); ?>
	<?php echo $form->error($model,'enddate'); ?></div>
	
	<?php if (!$model->isNewRecord): ?><div class="row">
	<?php echo $form->labelEx($model,'content_fotos'); ?>
	<?php $this->widget('ext.arrayfield.ArrayWidget', array(
		'name' => 'content_fotos',
		'values' => $model->content_fotos,
		'urlPart' => 'contentfoto',
		'connectionField' => 'content_id',
		'connectionId' => $model->getPrimaryKey(),
	)); ?></div><?php endif; ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'archive'); ?>
	<?php echo $form->checkBox($model,'archive'); ?>
	<?php echo $form->error($model,'archive'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'published'); ?>
	<?php echo $form->checkBox($model,'published'); ?>
	<?php echo $form->error($model,'published'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'language_rel'); ?>
	<?php echo $form->dropDownList($model,'language_rel', Language::getDropdownList(true)); ?>
	<?php echo $form->error($model,'language_rel'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'trainer_id'); ?>
	<?php echo $form->dropDownList($model,'trainer_id', Trainer::getDropdownList(true)); ?>
	<?php echo $form->error($model,'trainer_id'); ?></div>
		
	<div class="row">
<?php echo $form->labelEx($model,'clients'); ?>
<?php echo CHtml::activeDropDownList($model, 'clients', Client::getDropdownList(), array('multiple' => true, 'class' => 'chzn-select', 'style' => 'width:380px;')) ?>
<?php echo $form->error($model,'clients'); ?>
</div>

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('content/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
	<?php $this->widget( 'ext.EChosen.EChosen' ); ?>
</div><!-- form -->