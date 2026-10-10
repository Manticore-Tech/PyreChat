package dev.pyrearms.pyrechat_flutter

import android.app.job.JobParameters
import android.app.job.JobService

/**
 * Native RCS retry survives ordinary Flutter/UI process shutdowns. JobScheduler
 * may defer execution under Doze, force-stop, data saver or battery restrictions.
 */
class PyreRcsDeliveryJobService : JobService() {
    @Volatile
    private var worker: Thread? = null

    override fun onStartJob(params: JobParameters): Boolean {
        worker = Thread {
            val completed = PyreRcsBackgroundDelivery.flush(applicationContext)
            jobFinished(params, !completed)
        }.apply {
            name = "PyreRcsDelivery"
            start()
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        worker?.interrupt()
        worker = null
        return true
    }
}
