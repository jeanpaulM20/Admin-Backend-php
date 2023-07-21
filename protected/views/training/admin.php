<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('training/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete training with id ' + id)) {
					$.post('<?php echo $this->createUrl('training/delete'); ?>/' + id + '?ajax=1', {
					}, function() {
						window.location.reload();
					});
				}
				break;
		}
	}
</script>
<?php
$this->breadcrumbs = array(
	'Trainings'
);
$pageSize = Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Trainings</h1>

<p>
	You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
	or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>

<?php
$nextTraining = $model->getNextTraining();
?>
<?php if ($nextTraining): ?>
	<div style="border: 1px solid #000; padding: 10px;">
		<h4>Next training</h4>
		<p>
			<?php echo $nextTraining->getModelDisplay() ?><br/>
			<?php echo $nextTraining->type->name_en ?><br/>
			Message: <?php echo $nextTraining->text ?><br/>
			Client: <?php echo $nextTraining->client->getModelDisplay() ?><br/>
			Location: <?php echo $nextTraining->location->getModelDisplay() ?><br/>
			<?php if ($nextTraining->trainer): ?>
				Trainer: <?php echo $nextTraining->trainer->getModelDisplay() ?><br/>
			<?php endif; ?>
			<br/><a href="<?php echo $this->createUrl('training/update', array('id' => $nextTraining->id)); ?>">Edit</a>
		</p>
	</div><br/>
<?php endif; ?>

<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php
$this->widget('zii.widgets.grid.CGridView', array(
	'id' => 'training-grid',
	'dataProvider' => $model->search(),
	'filter' => $model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('training-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns' => array(
		'id',
		array(
			'name' => 'date',
			'class' => 'application.extensions.datecolumn.SYDateColumn',
		),
		'starttime',
		'duration',
		array(
			'name' => 'type_id',
			'value' => '$data->type->name_en',
			'filter' => TrainingType::getDropdownList(true),
		),
		'text',
		array(
			'name' => 'status',
			'value' => array($this, 'gridStatusColumn'),
			'filter' => $this->getModel()->getStatusValues(),
		),
		array(
			'name' => 'cancelled_at',
			'class' => 'application.extensions.datecolumn.SYDateColumn',
		),
		array(
			'name' => 'cancelled_by_client_search',
			'value' => '$data->cancelled_by_client->clientid  . " " . $data->cancelled_by_client->surname  . " " . $data->cancelled_by_client->name ',
		),
		array(
			'name' => 'cancelled_by_trainer_search',
			'value' => '$data->cancelled_by_trainer->surname  . " " . $data->cancelled_by_trainer->name ',
		),
		array(
			'name' => 'client_search',
			'value' => '$data->client->clientid  . " " . $data->client->surname  . " " . $data->client->name ',
		),
		array(
			'name' => 'location_search',
			'value' => '$data->location->name ',
		),
		array(
			'name' => 'trainer_search',
			'value' => '$data->trainer->surname  . " " . $data->trainer->name ',
		),
		array(
			'header' => 'Action',
			'type' => 'raw',
			'value' => array($this, 'gridActionColumn')
		)
	),
));
?>

<?php
echo CHtml::htmlButton('New Training', array(
	'submit' => $this->createUrl('training/create', array('back' => 'admin'))
))
?>
<?php
echo CHtml::htmlButton('Manage Training types', array(
	'submit' => $this->createUrl('trainingtype/admin')
))
?>

<script type="text/javascript">
	$(document).ready(function() {
		$('#export-button').on('click', function() {
			$.fn.yiiGridView.doExport();
		});

		function getData() {
			var data = $('.filters input, .filters select').serialize() + '&export=true';
<?php if (isset($_GET[$model->search()->getPagination()->pageVar])): ?>
				data += '&<?php echo $model->search()->getPagination()->pageVar ?>=<?php echo $_GET[$model->search()->getPagination()->pageVar] ?>';
<?php endif; ?>
			return data;
		}

		$.fn.yiiGridView.doExport = function() {
			$.fn.yiiGridView.update('training-grid', {
				success: function() {
					$('#training-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('training/exportFile') ?>';
				},
				data: getData()
			});
		}
		$('.grid-view .items tbody tr').live('dblclick', function() {
			var id_class;
			$($(this).attr('class').split(' ')).each(function() {
				if (this.indexOf('id_') === 0) {
					id_class = this;
				}
			});
			processAction('update', id_class.replace('id_', ''));
		});
	});
</script>