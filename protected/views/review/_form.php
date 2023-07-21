<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'review-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('review/create') : $this->createUrl('review/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'file'); ?>
<?php $this->widget('application.extensions.elfinder.FilePicker',array(
	'model'=>$model,
	'attribute'=>'file',
)); ?>	<?php echo $form->error($model,'file'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'duration'); ?>
	<?php echo $form->textField($model,'duration',array('size'=>60)); ?>
	<?php echo $form->error($model,'duration'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'kcal'); ?>
	<?php echo $form->textField($model,'kcal',array('size'=>60)); ?>
	<?php echo $form->error($model,'kcal'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'heart_rate'); ?>
	<?php echo $form->textField($model,'heart_rate',array('size'=>60)); ?>
	<?php echo $form->error($model,'heart_rate'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'exerciseset_id'); ?>
	<?php echo $form->dropDownList($model,'exerciseset_id', Exerciseset::getDropdownList()); ?>
	<?php echo $form->error($model,'exerciseset_id'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'training_id'); ?>
	<?php echo $form->dropDownList($model,'training_id', Training::getDropdownList()); ?>
	<?php echo $form->error($model,'training_id'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'trainingplan_id'); ?>
	<?php echo $form->dropDownList($model,'trainingplan_id', TrainingPlan::getDropdownList(true)); ?>
	<?php echo $form->error($model,'trainingplan_id'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'training_type'); ?>
	<?php echo $form->dropDownList($model,'training_type', Review::getTrainingTypes()); ?>
	<?php echo $form->error($model,'training_type'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'type'); ?>
	<?php echo $form->dropDownList($model,'type', Review::getTypes()); ?>
	<?php echo $form->error($model,'type'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'goal'); ?>
	<?php echo $form->textField($model,'goal',array('size'=>60)); ?> <?php echo $form->dropDownList($model,'goal_metric', Review::getMetrics()); ?>
	<?php echo $form->error($model,'goal'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'bonus_goal'); ?>
	<?php echo $form->textField($model,'bonus_goal',array('size'=>60)); ?> <?php echo $form->dropDownList($model,'bonus_goal_metric', Review::getMetrics()); ?>
	<?php echo $form->error($model,'bonus_goal'); ?></div>
	
	<div class="row">
	<?php echo $form->labelEx($model,'result'); ?>
	<?php echo $form->textField($model,'result',array('size'=>60)); ?>
	<?php echo $form->error($model,'result'); ?>
	</div>
	
	<?php if (!$model->isNewRecord): ?><div class="row">
	<?php echo $form->labelEx($model,'heart_rate_timeseries'); ?>
	<?php $this->widget('ext.arrayfield.ArrayWidget', array(
		'name' => 'heart_rate_timeseries',
		'values' => $model->review_heart_rate_timeseries,
		'urlPart' => 'reviewheartratetimeseries',
		'connectionField' => 'review_id',
		'connectionId' => $model->getPrimaryKey(),
	)); ?></div><?php endif; ?>

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('review/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->