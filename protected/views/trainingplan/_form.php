<div class="">

	<?php
	$cs = Yii::app()->clientScript;
	$cs->registerCoreScript('jquery.ui');
	$cs->registerCssFile($cs->getCoreScriptUrl(). '/jui/css/base/jquery-ui.css'); 
	$form = $this->beginWidget('CActiveForm', array(
		'id'					 => 'trainingplan-form',
		'enableAjaxValidation'	 => false,
		'action'				 => $model->isNewRecord ? $this->createUrl('trainingplan/create') : $this->createUrl('trainingplan/update', array('id' => $model->id)),
		'htmlOptions'	 => array('enctype' => 'multipart/form-data'),
	));
	?>
	<?php echo $form->hiddenField($model, 'id'); ?>
	<?php echo $form->errorSummary($model); ?>
	<div id="foto">
		<?php if ($model->client && $model->client->foto): ?>
			<img src="<?php echo $model->client->foto ?>" />
		<?php endif; ?>
	</div>
	<br/>
	<div class="column">
		<div class="left" style="width: 49%; text-align: right;">
			<?php echo $form->labelEx($model, 'client_id'); ?>
			<?php echo $form->labelEx($model, 'load_duration'); ?>
			<?php echo $form->labelEx($model, 'personal_week'); ?>
		</div>
		<div class="right" style="width: 49%;">
			<?php echo $form->dropDownList($model, 'client_id', Client::getDropdownList(), array('id' => 'client_select')); ?><br>
			<?php echo $form->textField($model, 'load_duration', array('style' => 'width: 50px;')); ?><br/>
			<?php echo $form->textField($model, 'personal_week', array('style' => 'width: 50px;')); ?>
		</div>
		<div class="clear"></div>
	</div>
	<div class="column">
		<div class="left" style="width: 49%; text-align: right;">
			<?php echo $form->labelEx($model, 'new_pro'); ?> 
			<?php echo $form->labelEx($model, 'repeat'); ?> 
			<?php echo $form->labelEx($model, 'own_week'); ?> 
		</div>
		<div class="right" style="width: 49%;">
			<?php echo $form->textField($model, 'new_pro'); ?><br/>
			<?php echo $form->textField($model, 'repeat', array('style' => 'width: 50px;')); ?><br/>
			<?php echo $form->textField($model, 'own_week', array('style' => 'width: 50px;')); ?>
		</div>
		<div class="clear"></div>
	</div>
	<div class="column inlabel">
		<div style="height: 2.2em;"></div>
		<?php echo $form->labelEx($model, 'temp'); ?> <?php echo $form->textField($model, 'temp', array('style' => 'width: 70px;')); ?>
		<?php echo $form->labelEx($model, 'rates'); ?> <?php echo $form->textField($model, 'rates', array('style' => 'width: 30px;')); ?>
		<?php echo $form->labelEx($model, 'phase'); ?> <?php echo $form->textField($model, 'phase', array('style' => 'width: 50px;')); ?>
		<br/>
		<?php echo $form->labelEx($model, 'goal'); ?> <?php echo $form->textField($model, 'goal', array('style' => 'width: 245px; margin-left: 18px;')); ?>
	</div>	
	<div class="clear"></div>
	<br/>
	<?php $values = $model->getValues();?>
	<table class="trainingplan-values" width="100%" cellspacing="0" cellpadding="0">
		<tr>
			<th>&nbsp;</th>
			<th>&Uuml;bungen</th>
			<th>Ger&auml;t</th>
			<th>Position</th>
			<th>Gewicht /<br/>Inten.</th>
			<?php for ($i = 0; $i < 8; $i++): ?>
			<th><input class="date dateinput" type="text" name="TrainingPlan[values][dates][<?php echo $i ?>]" placeholder="Datum" value="<?php echo isset($values['dates'][$i]) ? $values['dates'][$i] : '' ?>" /></th>
			<?php endfor; ?>
		</tr>
		<?php foreach ($values['sonsomo'] as $key => $row): ?>
			<tr>
			<?php if ($key == 0):?>
			<td rowspan="<?php echo count($values['sonsomo']) ?>">Son<br/>somo.</td>
			<?php endif; ?>
			<td><input class="exercise" type="text" name="TrainingPlan[values][sonsomo][<?php echo $key ?>][exercise]" value="<?php echo $row['exercise']?>" /></td>
			<td><input class="device" type="text" name="TrainingPlan[values][sonsomo][<?php echo $key ?>][device]" value="<?php echo $row['device']?>" /></td>
			<td><input class="position" type="text" name="TrainingPlan[values][sonsomo][<?php echo $key ?>][position]" value="<?php echo $row['position']?>" /></td>
			<td><input class="weight" type="text" name="TrainingPlan[values][sonsomo][<?php echo $key ?>][weight]" value="<?php echo $row['weight']?>" /></td>
			<?php for ($j = 0; $j < 8; $j++): ?>
			<th><input class="date" type="text" name="TrainingPlan[values][sonsomo][<?php echo $key ?>][dates][<?php echo $j ?>]" value="<?php echo isset($row['dates'][$j]) ? $row['dates'][$j] : '' ?>" /></th>
			<?php endfor; ?>
			</tr>
		<?php endforeach; ?>
		<?php foreach ($values['main'] as $key => $row):?>
			<tr>
			<?php if ($key == 0):?>
			<td rowspan="<?php echo count($values['main']) ?>">Haup<br/>teil</td>
			<?php endif; ?>
			<td><input class="exercise" type="text" name="TrainingPlan[values][main][<?php echo $key ?>][exercise]" value="<?php echo $row['exercise']?>" /></td>
			<td><input class="device" type="text" name="TrainingPlan[values][main][<?php echo $key ?>][device]" value="<?php echo $row['device']?>" /></td>
			<td><input class="position" type="text" name="TrainingPlan[values][main][<?php echo $key ?>][position]" value="<?php echo $row['position']?>" /></td>
			<td><input class="weight" type="text" name="TrainingPlan[values][main][<?php echo $key ?>][weight]" value="<?php echo $row['weight']?>" /></td>
			<?php for ($j = 0; $j < 8; $j++): ?>
			<th><input class="date" type="text" name="TrainingPlan[values][main][<?php echo $key ?>][dates][<?php echo $j ?>]" value="<?php echo isset($row['dates'][$j]) ? $row['dates'][$j] : '' ?>" /></th>
			<?php endfor; ?>
			</tr>
		<?php endforeach; ?>
		<?php foreach ($values['core'] as $key => $row):?>
			<tr>
			<?php if ($key == 0):?>
			<td rowspan="<?php echo count($values['core']) ?>">Core<br/>training</td>
			<?php endif; ?>
			<td><input class="exercise" type="text" name="TrainingPlan[values][core][<?php echo $key ?>][exercise]" value="<?php echo $row['exercise']?>" /></td>
			<td><input class="device" type="text" name="TrainingPlan[values][core][<?php echo $key ?>][device]" value="<?php echo $row['device']?>" /></td>
			<td><input class="position" type="text" name="TrainingPlan[values][core][<?php echo $key ?>][position]" value="<?php echo $row['position']?>" /></td>
			<td><input class="weight" type="text" name="TrainingPlan[values][core][<?php echo $key ?>][weight]" value="<?php echo $row['weight']?>" /></td>
			<?php for ($j = 0; $j < 8; $j++): ?>
			<th><input class="date" type="text" name="TrainingPlan[values][core][<?php echo $key ?>][dates][<?php echo $j ?>]" value="<?php echo isset($row['dates'][$j]) ? $row['dates'][$j] : '' ?>" /></th>
			<?php endfor; ?>
			</tr>
		<?php endforeach; ?>	
	</table>
	
	<div class="row">
		<?php echo $form->labelEx($model,'type'); ?>
		<?php echo $form->dropDownList($model, 'type', TrainingPlan::getTypeValues()); ?>
		<?php echo $form->error($model,'type'); ?>
	</div>
	
	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
		echo CHtml::htmlButton('Cancel', array(
			'onclick' => 'window.location="' . $this->createUrl('trainingplan/admin') . '";'
		));
		?>
	</div>

<?php $this->endWidget(); ?>
<?php $this->widget('ext.EChosen.EChosen'); ?>	
</div><!-- form -->
<script type="text/javascript">
	$(document).ready(function(){
		$('.dateinput').datepicker({ dateFormat: "dd.mm.yy" });
		$('#client_select').change(function(e){
			$('#foto').load('<?php echo $this->createUrl('client/foto') ?>/' + $(this).val());
		});
		$('input, select').blur(function(){
			$.post('<?php echo $this->createUrl('trainingplan/autosave') ?>', $('#trainingplan-form').serialize(), function(data) {
				var obj = $.parseJSON(data);
				$('#TrainingPlan_id').val(obj.id);
			});
		});
	});
</script>